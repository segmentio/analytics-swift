//
//  FlushPolicy_Tests.swift
//
//
//  Created by Alan Charles on 4/11/23.
//

import XCTest
@testable import Segment

class DummyFlushPolicy: FlushPolicy {
    var analytics: Segment.Analytics?
    
    func configure(analytics: Segment.Analytics) {
        
    }
    
    func shouldFlush() -> Bool {
        return true
    }
    
    func updateState(event: Segment.RawEvent) {
        
    }
    
    func reset() {
        
    }
}

class FlushPolicyTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testAddFlushPolicy() {
        // Use a specific writekey to this test so we do not collide with other cached items.
        let analytics = Analytics(configuration: Configuration(writeKey: "flushPolicyAddTest"))
        
        let dummy = DummyFlushPolicy()
        analytics.add(flushPolicy: dummy)
        
        waitUntilStarted(analytics: analytics)
        
        let policies = analytics.configuration.values.flushPolicies
        
        XCTAssert(policies.contains(where: { flushPolicy in
            flushPolicy === dummy
        }))
    }
    
    func testRemoveFlushPolicy() {
        let analytics = Analytics(configuration: Configuration(writeKey: "flushPolicyAddTest"))
        
        let dummy = DummyFlushPolicy()
        analytics.add(flushPolicy: dummy)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.remove(flushPolicy: dummy)
        
        let policies = analytics.configuration.values.flushPolicies
        
        XCTAssertFalse(policies.contains(where: { flushPolicy in
            flushPolicy === dummy
        }))
    }
    
    func testRemoveAllFlushPolicies() {
        let analytics = Analytics(configuration: Configuration(writeKey: "flushPolicyAddTest"))
        var policies = analytics.configuration.values.flushPolicies
        
        waitUntilStarted(analytics: analytics)
        
        XCTAssertFalse(policies.isEmpty)
        
        analytics.removeAllFlushPolicies()
        
        policies = analytics.configuration.values.flushPolicies
        
        XCTAssert(policies.isEmpty)
    }
    
    func testFindFlushPolicy() {
        let analytics = Analytics(configuration: Configuration(writeKey: "flushPolicyAddTest"))
        
        waitUntilStarted(analytics: analytics)
        
        let policy =  analytics.find(flushPolicy: CountBasedFlushPolicy.self)
        
        XCTAssertNotNil(policy)
    }
    
    func testCountBasedFlushPolicy() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "countFlushPolicy"))
        let countFlush = CountBasedFlushPolicy(count: 3)
        analytics.add(flushPolicy: countFlush)
        
        waitUntilStarted(analytics: analytics)
        
        let event = TrackEvent(event: "blah", properties: nil)
        
        // 0 -- we ain't had no events come through Chawnchy.
        XCTAssertFalse(countFlush.shouldFlush())
        
        // 1
        countFlush.updateState(event: event)
        XCTAssertFalse(countFlush.shouldFlush())
        // 2
        countFlush.updateState(event: event)
        XCTAssertFalse(countFlush.shouldFlush())
        
        countFlush.updateState(event: event)
        // we now have ONE HA HA.  TWO HA HA .. 3 ... HA HA THREE!  Items to flush!  <flys aways>
        XCTAssertTrue(countFlush.shouldFlush())
    }

    func testIntervalBasedFlushPolicy() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "intervalFlushPolicy"))
        
        //remove default flush policies
        analytics.removeAllFlushPolicies()
        
        // make sure storage has no old events
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        
        let intervalFlush = IntervalBasedFlushPolicy(interval: 2)
        analytics.add(flushPolicy: intervalFlush)
        
        waitUntilStarted(analytics: analytics)
        analytics.track(name: "blah", properties: nil)
        
        XCTAssertTrue(analytics.hasUnsentEvents)
        
        @Atomic var flushSent = false
        while !flushSent {
            RunLoop.main.run(until: Date.distantPast)
            if analytics.pendingUploads!.count > 0 {
                // flush was triggered
                _flushSent.set(true)
            }
        }
        
        XCTAssertTrue(flushSent)
    }
}
