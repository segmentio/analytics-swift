//
//  StressTests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 11/4/21.
//

import XCTest
@testable import Segment

class StressTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // Linux doesn't know what URLProtocol is and on watchOS it somehow works differently and isn't hit.
    #if !os(Linux) && !os(watchOS)
    func testStorageStress() throws {
        // register our network blocker
        guard URLProtocol.registerClass(BlockNetworkCalls.self) else { XCTFail(); return }
                
        let analytics = Analytics(configuration: Configuration(writeKey: "stressTest").errorHandler({ error in
            XCTFail("Storage Error: \(error)")
        }))
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        analytics.storage.onFinish = { url in
            // check that each one is valid json
            do {
                let json = try Data(contentsOf: url)
                _ = try JSONSerialization.jsonObject(with: json)
            } catch {
                XCTFail("\(error) in \(url)")
            }
        }

        waitUntilStarted(analytics: analytics)
        
        // set the httpclient to use our blocker session
        let segment = analytics.find(pluginType: SegmentDestination.self)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForResource = 30
        configuration.timeoutIntervalForRequest = 60
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.protocolClasses = [BlockNetworkCalls.self]
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json; charset=utf-8",
                                               "Authorization": "Basic test",
                                               "User-Agent": "analytics-ios/\(Analytics.version())"]
        let blockSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        segment?.httpClient?.session = blockSession
        
        let writeQueue1 = DispatchQueue(label: "write queue 1")
        let writeQueue2 = DispatchQueue(label: "write queue 2")
        let flushQueue = DispatchQueue(label: "flush queue")
        
        @Atomic var ready = false
        @Atomic var queue1Done = false
        @Atomic var queue2Done = false
        
        writeQueue1.async {
            while (ready == false) { usleep(1) }
            var eventsWritten = 0
            while (eventsWritten < 10000) {
                let event = "write queue 1: \(eventsWritten)"
                analytics.track(name: event)
                eventsWritten += 1
                usleep(0001)
            }
            print("queue 1 wrote \(eventsWritten) events.")
            queue1Done = true
        }
        
        writeQueue2.async {
            while (ready == false) { usleep(1) }
            var eventsWritten = 0
            while (eventsWritten < 10000) {
                let event = "write queue 2: \(eventsWritten)"
                analytics.track(name: event)
                eventsWritten += 1
                usleep(0001)
            }
            print("queue 2 wrote \(eventsWritten) events.")
            queue2Done = true
        }
        
        flushQueue.async {
            while (ready == false) { usleep(1) }
            var counter = 0
            sleep(1)
            while (queue1Done == false || queue2Done == false) {
                let sleepTime = UInt32.random(in: 1..<3000)
                usleep(sleepTime)
                analytics.flush()
                counter += 1
            }
            print("flushed \(counter) times.")
            ready = false
        }
        
        ready = true
        
        while (ready) {
            RunLoop.main.run(until: Date.distantPast)
        }
    }
    #endif
     
    
    /*func testStressXTimes() throws {
        for i in 0..<50 {
            print("Stress test #\(i):")
            try testStorageStress()
            print("\n")
        }
    }*/
     
}
