//
//  StorageTests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 1/7/21.
//

import XCTest
@testable import Segment

class StorageTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testSettingsWrite() throws {
        let dummySettings = """
        {
            "integrations": {
              "Segment.io": {
                "apiKey": "1234",
                "unbundledIntegrations": [],
                "addBundledMetadata": true
              }
            },
            "middlewareSettings": {
              "routingRules": [
                {
                  "transformers": [
                    [
                      {
                        "type": "allow_properties",
                        "config": {
                          "allow": {
                            "traits": null,
                            "context": null,
                            "_metadata": null,
                            "integrations": null,
                          }
                        }
                      }
                    ]
                  ]
                }
              ]
            },
          }
        """
        let jsonData = dummySettings.data(using: .utf8)!
        let jsonSettings = try! JSONSerialization.jsonObject(with: jsonData)
        
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        analytics.waitUntilStarted()
        // this will crash if it fails.
        let j = try! JSON(jsonSettings)
        analytics.storage.write(.settings, value: j)
        
        RunLoop.main.run(until: Date.distantPast)
        
        let result: JSON? = analytics.storage.read(.settings)

        XCTAssertNotNil(result)
    }

    func testBasicWriting() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics.waitUntilStarted()
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let userInfo: UserInfo? = analytics.store.currentState()
        XCTAssertNotNil(userInfo)
        XCTAssertTrue(userInfo!.userId == "brandon")
        
        // This is a hack that needs to be dealt with
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        
        if let userId = analytics.storage.userDefaults.string(forKey: Storage.Constants.userId.rawValue) {
            XCTAssertTrue(userId == "brandon")
        } else {
            XCTFail("Could not read from storage the userId")
        }
    }
    
    func testEventWriting() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        analytics.waitUntilStarted()
        
        let existing = analytics.storage.read(.events)?.dataFiles
        XCTAssertNil(existing)
        
        var event = IdentifyEvent(userId: "brandon1", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon2", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon3", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        let results = analytics.storage.read(.events)

        XCTAssertNotNil(results)
        
        let fileURL = results!.dataFiles![0]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "0-segment-events.temp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let json = try! JSONSerialization.jsonObject(with: Data(contentsOf: fileURL), options: []) as! [String: Any]
        
        let batch = json["batch"] as! [[String: Any]]
        let item1 = batch[0]["userId"] as! String
        let item2 = batch[1]["userId"] as! String
        let item3 = batch[2]["userId"] as! String

        XCTAssertTrue(item1 == "brandon1")
        XCTAssertTrue(item2 == "brandon2")
        XCTAssertTrue(item3 == "brandon3")

        analytics.storage.remove(data: results!.removable)

        // make sure our original and temp files are named correctly, and gone.
        let originalFile = fileURL.deletingPathExtension()
        let tempFile = fileURL
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path))
    }
    
    func testFilePrepAndFinish() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        analytics.waitUntilStarted()
        
        var event = IdentifyEvent(userId: "brandon1", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        var results = analytics.storage.read(.events)

        XCTAssertNotNil(results)
        
        var fileURL = results!.dataFiles![0]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "0-segment-events.temp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        event = IdentifyEvent(userId: "brandon2", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        results = analytics.storage.read(.events)
        
        XCTAssertNotNil(results)
        
        fileURL = results!.dataFiles![1]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "1-segment-events.temp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testMemoryStorageRolloff() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test")
            .storageMode(.memory(10))
            .trackApplicationLifecycleEvents(false)
        )
        
        analytics.waitUntilStarted()
        
        XCTAssertEqual(analytics.storage.dataStore.count, 0)
        
        for i in 0..<9 {
            analytics.track(name: "Event \(i)")
        }
        
        let second = analytics.storage.dataStore.fetch(count: 2)!.removable![1] as! UUID
        
        XCTAssertEqual(analytics.storage.dataStore.count, 9)
        analytics.track(name: "Event 10")
        XCTAssertEqual(analytics.storage.dataStore.count, 10)
        analytics.track(name: "Event 11")
        XCTAssertEqual(analytics.storage.dataStore.count, 10)
        
        let events = analytics.storage.read(.events)!
        // see that the first one "Event 0" went away
        XCTAssertEqual(events.removable![0] as! UUID, second)
        
        let json = try! JSONSerialization.jsonObject(with: events.data!) as! [String: Any]
        let batch = json["batch"] as! [Any]
        XCTAssertEqual(batch.count, 10)
        
        RunLoop.main.run(until: Date.init(timeIntervalSinceNow: 3))
        waitUntilFinished(analytics: analytics)
    }
    
    func testMemoryStorageSizeLimitsSync() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testMemorySync")
            .storageMode(.memory(10000000000))
            .operatingMode(.synchronous)
            .trackApplicationLifecycleEvents(false)
            .flushAt(9999999999)
            .flushInterval(9999999999)
        )
        
        analytics.waitUntilStarted()
        
        XCTAssertEqual(analytics.storage.dataStore.count, 0)
        
        analytics.track(name: "First Event")
        
        // write 475000 bytes worth of events (approx 602) + some extra
        for i in 0..<900 {
            analytics.track(name: "Event \(i)")
        }
        
        let dataCount = analytics.storage.read(.events)!.removable!.count
        let totalCount = analytics.storage.dataStore.count
        
        print(dataCount)
        print(totalCount)
        
        let events = analytics.storage.read(.events)!
        XCTAssertTrue(events.data!.count < 500_000)
        
        // just to be sure we can serialize the thing .. this will crash if it fails.
        let json = try! JSONSerialization.jsonObject(with: events.data!) as! [String: Any]
        let batch = json["batch"] as! [Any]
        
        // batch counts won't be equal every test.  fields within each event
        // changes like timestamp, os version, userAgent, etc etc.  so this
        // is the best we can really do.  Be sure it's not ALL of them.
        XCTAssertTrue(batch.count < 900)
        
        // should be sync cuz that's our operating mode
        analytics.flush {
            print("flush completed")
        }
        
        // we flushed them all
        let remaining = analytics.storage.read(.events)
        XCTAssertNil(remaining)
    }
    
    func testMemoryStorageSizeLimitsAsync() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testMemoryAsync")
            .storageMode(.memory(10000000000))
            .operatingMode(.asynchronous)
            .trackApplicationLifecycleEvents(false)
            .flushAt(9999999999)
            .flushInterval(9999999999)
        )
        
        analytics.waitUntilStarted()
        
        XCTAssertEqual(analytics.storage.dataStore.count, 0)
        
        analytics.track(name: "First Event")
        
        // write 475000 bytes worth of events (approx 602) + some extra
        for i in 0..<900 {
            analytics.track(name: "Event \(i)")
        }
        
        let dataCount = analytics.storage.read(.events)!.removable!.count
        let totalCount = analytics.storage.dataStore.count
        
        print(dataCount)
        print(totalCount)
        
        let events = analytics.storage.read(.events)!
        XCTAssertTrue(events.data!.count < 500_000)
        
        let json = try! JSONSerialization.jsonObject(with: events.data!) as! [String: Any]
        let batch = json["batch"] as! [Any]
        // batch counts won't be equal every test.  fields within each event
        // changes like timestamp, os version, userAgent, etc etc.  so this
        // is the best we can really do.  Be sure it's not ALL of them.
        XCTAssertTrue(batch.count < 900)
        
        // should be sync cuz that's our operating mode
        @Atomic var done = false
        analytics.flush {
            print("flush completed")
            _done.set(true)
        }
        
        while !done {
            RunLoop.main.run(until: .distantPast)
        }
        
        // we flushed them all, not just the first batch
        let remaining = analytics.storage.read(.events)
        XCTAssertNil(remaining)
    }
}
