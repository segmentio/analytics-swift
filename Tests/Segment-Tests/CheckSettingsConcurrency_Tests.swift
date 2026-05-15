//
//  CheckSettingsConcurrency_Tests.swift
//  Segment-Tests
//

import XCTest
@testable import Segment

class CheckSettingsConcurrency_Tests: XCTestCase {

    override func setUpWithError() throws {
        Telemetry.shared.enable = false
    }

    func testTryBeginCheckingSettingsReturnsTrueWhenFlagIsClear() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)
        analytics.endCheckingSettings()

        XCTAssertTrue(analytics.tryBeginCheckingSettings())
        XCTAssertTrue(analytics.isCheckingSettings)
    }

    func testTryBeginCheckingSettingsReturnsFalseWhenFlagIsSet() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        XCTAssertTrue(analytics.tryBeginCheckingSettings())
        XCTAssertFalse(analytics.tryBeginCheckingSettings())
    }

    func testEndCheckingSettingsClearsFlag() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        _ = analytics.tryBeginCheckingSettings()
        XCTAssertTrue(analytics.isCheckingSettings)

        analytics.endCheckingSettings()
        XCTAssertFalse(analytics.isCheckingSettings)
    }

    func testCheckSettingsClearsFlagAfterCompletion() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)

        analytics.checkSettings()

        let expectation = XCTestExpectation(description: "flag cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(analytics.isCheckingSettings)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testConcurrentCheckSettingsCallsOnlyOneProceeds() {
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        waitUntilStarted(analytics: analytics)
        analytics.endCheckingSettings()

        var winners = 0
        let lock = NSLock()
        let group = DispatchGroup()

        for _ in 0..<32 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                if analytics.tryBeginCheckingSettings() {
                    lock.lock()
                    winners += 1
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.wait()
        XCTAssertEqual(winners, 1)
    }
}
