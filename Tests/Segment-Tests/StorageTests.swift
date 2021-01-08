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

    func testBasicWriting() throws {
        let analytics = Analytics(writeKey: "1234").build()
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let userInfo: UserInfo? = analytics.store.currentState()
        XCTAssertNotNil(userInfo)
        XCTAssertTrue(userInfo!.userId == "brandon")
        
        //RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        
        let userId = analytics.storage.userDefaults?.value(forKey: Storage.Constants.userId.rawValue) as! String
        XCTAssertTrue(userId == "brandon")
    }
    
    func testEventWriting() throws {
        let analytics = Analytics(writeKey: "1234").build()
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        var event = IdentifyEvent(userId: "brandon1", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon2", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon3", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        let results: [URL]? = analytics.storage.read(.events)

        XCTAssertNotNil(results)
        
        let fileURL = results![0]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "0.segment.events")
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
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testFilePrepAndFinish() {
        let analytics = Analytics(writeKey: "1234").build()
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        var event = IdentifyEvent(userId: "brandon1", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        var results: [URL]? = analytics.storage.read(.events)

        XCTAssertNotNil(results)
        
        var fileURL = results![0]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "0.segment.events")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        event = IdentifyEvent(userId: "brandon2", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        results = analytics.storage.read(.events)
        
        XCTAssertNotNil(results)
        
        fileURL = results![0]
        
        XCTAssertTrue(fileURL.isFileURL)
        XCTAssertTrue(fileURL.lastPathComponent == "1.segment.events")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
