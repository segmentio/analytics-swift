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
        Storage.hardSettingsReset(writeKey: "WRITE_KEY")
        let config = ObjCConfiguration(writeKey: "WRITE_KEY")
        config.defaultSettings = ["integrations": ["Amplitude": true]]
        
        let analytics = ObjCAnalytics(configuration: config)
        analytics.reset()
        
        analytics.identify(userId: "testPerson", traits: ["email" : "blah@blah.com"])
        
        waitUntilStarted(analytics: analytics.analytics)
        
        let settings = analytics.settings()
        let integrations = settings?["integrations"] as? [String: Any]
        
        XCTAssertTrue(integrations != nil)
        XCTAssertTrue(integrations?["Amplitude"] as? Bool == true)
        
        let traits = analytics.traits()
        XCTAssertTrue(traits != nil)
        XCTAssertTrue(traits?["email"] as? String == "blah@blah.com")
        
        let userId = analytics.userId
        XCTAssertTrue(userId == "testPerson")
    }
    
    func testTraitsAndUserIdOptionality() {
        let config = ObjCConfiguration(writeKey: "WRITE_KEY")
        let analytics = ObjCAnalytics(configuration: config)
        analytics.reset()
        
        analytics.identify(userId: nil, traits: ["email" : "blah@blah.com"])
        
        waitUntilStarted(analytics: analytics.analytics)
        let userId = analytics.userId
        XCTAssertNil(userId)
        let traits = analytics.traits()
        XCTAssertTrue(traits != nil)
        XCTAssertTrue(traits?["email"] as? String == "blah@blah.com")
    }
    
    func testObjCMiddlewares() {
        var sourceHit: Bool = false
        var destHit: Bool = false
        
        Storage.hardSettingsReset(writeKey: "WRITE_KEY")
        
        let config = ObjCConfiguration(writeKey: "WRITE_KEY")
        let analytics = ObjCAnalytics(configuration: config)
        analytics.analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        analytics.reset()
        
        let outputReader = OutputReaderPlugin()
        analytics.analytics.add(plugin: outputReader)
        
        let sourcePlugin = ObjCBlockPlugin { event in
            print("source enrichment applied")
            sourceHit = true
            return event
        }
        analytics.add(plugin: sourcePlugin)
        
        let destPlugin = ObjCBlockPlugin { event in
            print("destination enrichment applied")
            destHit = true
            return event
        }
        analytics.add(plugin: destPlugin, destinationKey: "Segment.io")
        
        waitUntilStarted(analytics: analytics.analytics)
        
        analytics.identify(userId: "batman")
        
        analytics.flush()
        
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
        
        XCTAssertTrue(sourceHit)
        XCTAssertTrue(destHit)
        
        let lastEvent = outputReader.lastEvent
        XCTAssertTrue(lastEvent is IdentifyEvent)
        XCTAssertTrue((lastEvent as! IdentifyEvent).userId == "batman")
    }
}

#endif
