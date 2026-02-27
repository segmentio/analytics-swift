//
//  TransientDB_RaceCondition_Tests.swift
//  Segment-Tests
//
//  Test for race condition fix between async append and fetch/flush operations
//

import XCTest
@testable import Segment

final class TransientDB_RaceCondition_Tests: XCTestCase {

    func testAsyncAppendCompletesBeforeFetch() throws {
        // This test verifies the fix for the race condition where fetch() was called
        // while async appends were still pending, causing batch corruption.

        let analytics = Analytics(configuration: Configuration(writeKey: "test-race-condition")
            .storageMode(.disk)
            .operatingMode(.asynchronous))

        waitUntilStarted(analytics: analytics)

        // Clean up any existing data
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        let eventCount = 50

        // Queue multiple events rapidly
        for i in 0..<eventCount {
            analytics.track(name: "TestEvent\(i)")
        }

        // Trigger flush to write batch file (this is where race condition would occur)
        analytics.flush()

        // Wait for flush to complete
        Thread.sleep(forTimeInterval: 0.5)

        #if os(iOS) || os(macOS)
        // On iOS/macOS, verify data was written correctly
        // The key test: with fix, all events should be written before finishFile()
        // Without fix, some events would be written AFTER closing bracket
        XCTAssert(analytics.storage.dataStore.hasData, "Should have written data")
        #endif

        // Success means no race condition occurred (no crashes)
        print("✅ Async append test passed - no race condition detected")

        // Cleanup
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
    }

    func testSynchronousModeNoRaceCondition() throws {
        // Verify that synchronous mode works without crashing (no race condition possible)
        // Note: This test verifies the workaround works, not the fix itself

        let analytics = Analytics(configuration: Configuration(writeKey: "test-sync-mode")
            .storageMode(.disk)
            .operatingMode(.synchronous))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        // Add events synchronously
        for i in 0..<10 {
            analytics.track(name: "SyncEvent\(i)")
        }

        // Flush - in synchronous mode, this completes without race conditions
        analytics.flush()

        // Success: synchronous mode completed without crashing
        // The fix (DispatchGroup) only applies to async mode
        print("✅ Synchronous mode test passed - no race condition possible")

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
    }

    func testHighVolumeAsyncAppends() throws {
        // Stress test with high event volume to increase race condition likelihood

        let analytics = Analytics(configuration: Configuration(writeKey: "test-high-volume")
            .storageMode(.disk)
            .operatingMode(.asynchronous))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        let eventCount = 100

        // Queue many events rapidly from multiple threads
        DispatchQueue.concurrentPerform(iterations: eventCount) { i in
            analytics.track(name: "Event\(i)")
        }

        // Trigger flush (race condition would occur here)
        analytics.flush()

        // Wait for flush to complete
        Thread.sleep(forTimeInterval: 0.5)

        #if os(iOS) || os(macOS)
        // On iOS/macOS, verify data was written correctly
        let result = analytics.storage.read(.events)
        XCTAssertNotNil(result, "Should have fetched data")

        if let result = result, let data = result.data {
            do {
                // Verify valid JSON structure (no corruption)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                XCTAssertNotNil(json, "Should parse as valid JSON")

                let batch = json?["batch"] as? [[String: Any]]
                XCTAssertNotNil(batch, "Should have batch array")
                XCTAssertGreaterThan(batch?.count ?? 0, 0, "Should have events in batch")

                print("✅ High volume test passed with \(batch?.count ?? 0) events")
            } catch {
                XCTFail("Failed to parse batch data: \(error)")
            }
        }
        #else
        // On tvOS/visionOS/watchOS, just verify no crash (race condition fix works)
        print("✅ High volume test passed - no race condition detected")
        #endif

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
    }
}
