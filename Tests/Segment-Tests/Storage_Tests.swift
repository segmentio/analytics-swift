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
        
        if let userId = analytics.storage.userDefaults?.string(forKey: Storage.Constants.userId.rawValue) {
            XCTAssertTrue(userId == "brandon")
        } else {
            XCTFail("Could not read from storage the userId")
        }
    }
    
    func testEventWriting() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        analytics.waitUntilStarted()
        
        var event = IdentifyEvent(userId: "brandon1", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon2", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon3", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        let results: [URL]? = analytics.storage.read(.events)

        XCTAssertNotNil(results)
        
        let fileURL = results![0]
        
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

        analytics.storage.remove(file: fileURL)

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
        
        var results: [URL]? = analytics.storage.read(.events)

        XCTAssertNotNil(results)
        
        var fileURL = results![0]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "0-segment-events.temp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        event = IdentifyEvent(userId: "brandon2", traits: try! JSON(with: MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        results = analytics.storage.read(.events)
        
        XCTAssertNotNil(results)
        
        fileURL = results![0]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "1-segment-events.temp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
}
