//
//  ObjC_Tests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 8/13/21.
//

#if !os(Linux)

import XCTest
@testable import Segment

class ObjC_Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /*

     NOTE: These tests only cover non-trivial methods.  Most ObjC methods pass straight through to their swift counterparts
     however, there are some where some data conversion needs to happen in order to be made accessible.
     
     */

    func testWrapping() {
        let a = Analytics(configuration: Configuration(writeKey: "WRITE_KEY"))
        let objc = ObjCAnalytics(wrapping: a)
        
        XCTAssertTrue(objc.analytics === a)
    }
    
    func testNonTrivialConfiguration() {
        let config = ObjCConfiguration(writeKey: "WRITE_KEY")
        config.defaultSettings = ["integrations": ["Amplitude": true]]
        
        let defaults = config.defaultSettings
        let integrations = defaults["integrations"] as? [String: Any]
        
        XCTAssertTrue(integrations != nil)
        XCTAssertTrue(integrations?["Amplitude"] as? Bool == true)
    }
    
    func testNonTrivialAnalytics() {
        let config = ObjCConfiguration(writeKey: "WRITE_KEY")
        config.defaultSettings = ["integrations": ["Amplitude": true]]
        
        let analytics = ObjCAnalytics(configuration: config)
        analytics.identify(userId: "testPerson", traits: ["email" : "blah@blah.com"])
        
        waitUntilStarted(analytics: analytics.analytics)
        
        let settings = analytics.settings()
        let integrations = settings?["integrations"] as? [String: Any]
        
        XCTAssertTrue(integrations != nil)
        XCTAssertTrue(integrations?["Amplitude"] as? Bool == true)
        
        let traits = analytics.traits()
        XCTAssertTrue(traits != nil)
        XCTAssertTrue(traits?["email"] as? String == "blah@blah.com")
    }
}

#endif
