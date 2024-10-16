//
//  HTTPClientTests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 1/21/21.
//

#if !os(Linux) && !os(Windows)

import XCTest
@testable import Segment

class HTTPClientTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
        RestrictedHTTPSession.reset()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCustomHTTPSessionUpload() throws {
        // Use a specific writekey to this test so we do not collide with other cached items.
        let analytics = Analytics(
            configuration: Configuration(writeKey: "testCustomSesh")
                .flushInterval(9999)
                .flushAt(9999)
                .httpSession(RestrictedHTTPSession())
        )
        
        waitUntilStarted(analytics: analytics)
        
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let flushDone = XCTestExpectation(description: "flush done")
        analytics.flush {
            flushDone.fulfill()
        }
    
        wait(for: [flushDone])
         
        XCTAssertEqual(RestrictedHTTPSession.fileUploads, 1)
    }
    
    func testDefaultHTTPSessionUpload() throws {
        // Use a specific writekey to this test so we do not collide with other cached items.
        let analytics = Analytics(
            configuration: Configuration(writeKey: "testDefaultSesh")
                .flushInterval(9999)
                .flushAt(9999)
        )
        
        // reach in and set it, would be the same as the default ultimately
        let segment = analytics.find(pluginType: SegmentDestination.self)
        XCTAssertTrue(!(segment?.httpClient?.session is RestrictedHTTPSession))
        XCTAssertTrue(segment?.httpClient?.session is URLSession)
        segment?.httpClient?.session = RestrictedHTTPSession()
        
        waitUntilStarted(analytics: analytics)
        
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let flushDone = XCTestExpectation(description: "flush done")
        analytics.flush {
            flushDone.fulfill()
        }
    
        wait(for: [flushDone])
         
        XCTAssertEqual(RestrictedHTTPSession.fileUploads, 1)
    }
}

#endif
