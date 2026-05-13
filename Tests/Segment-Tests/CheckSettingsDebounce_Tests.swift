//
//  CheckSettingsDebounce_Tests.swift
//  Segment-Tests
//

import XCTest
@testable import Segment

class CheckSettingsDebounce_Tests: XCTestCase {

    func testCheckSettingsIfNeededFiresOnFirstCall() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        // Back-date so the startup checkSettings() timestamp doesn't
        // block the first debounced call.
        analytics.recordSettingsCheckTimestamp(.distantPast)

        let before = analytics.lastSettingsCheck
        analytics.checkSettingsIfNeeded()
        XCTAssertGreaterThan(analytics.lastSettingsCheck, before)
    }

    func testCheckSettingsIfNeededIsDebouncedWithinWindow() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        analytics.checkSettingsIfNeeded()
        let firstStamp = analytics.lastSettingsCheck

        // Immediately re-call; should be a no-op — timestamp unchanged.
        analytics.checkSettingsIfNeeded()
        XCTAssertEqual(analytics.lastSettingsCheck, firstStamp)
    }

    func testCheckSettingsIfNeededFiresAgainAfterWindow() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        analytics.checkSettingsIfNeeded()

        // Simulate the debounce window having elapsed by back-dating.
        analytics.recordSettingsCheckTimestamp(.distantPast)

        let before = analytics.lastSettingsCheck
        analytics.checkSettingsIfNeeded()
        XCTAssertGreaterThan(analytics.lastSettingsCheck, before)
    }

    func testCheckSettingsAlwaysUpdatesTimestamp() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        analytics.recordSettingsCheckTimestamp(.distantPast)
        analytics.checkSettings()
        XCTAssertGreaterThan(analytics.lastSettingsCheck, .distantPast)
    }
}
