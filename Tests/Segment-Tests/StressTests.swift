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
    /* re-enable when network is mocked */
    /*
    func testStorageStress() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
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
    }*/


}
