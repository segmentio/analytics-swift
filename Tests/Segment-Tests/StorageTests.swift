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

    func testBasicWrite() throws {
        let analytics = Analytics(writeKey: "1234")
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        var event = IdentifyEvent(userId: "brandon1", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon2", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        event = IdentifyEvent(userId: "brandon3", traits: try! JSON(MyTraits(email: "blah@blah.com")))
        analytics.storage.write(.events, value: event)
        
        let results: [URL]? = analytics.storage.read(.events)
        print(results)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
