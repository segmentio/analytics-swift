//
//  CheckSettingsDebounce_Tests.swift
//  Segment-Tests
//

import XCTest
@testable import Segment

class CheckSettingsDebounce_Tests: XCTestCase {

    override func setUpWithError() throws {
        Telemetry.shared.enable = false
    }

    func testCheckSettingsIfNeededFiresOnFirstCall() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)
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
        analytics.checkSettingsIfNeeded()

        XCTAssertEqual(analytics.lastSettingsCheck, firstStamp)
    }

    func testCheckSettingsIfNeededFiresAgainAfterWindow() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        analytics.checkSettingsIfNeeded()
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
