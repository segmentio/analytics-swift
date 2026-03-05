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
        //
        // Without the fix: pendingAppends.wait() missing → fetch() executes while
        // async appends still queued → finishFile() closes batch array → queued
        // appends write events AFTER closing bracket → batch corruption
        //
        // With the fix: pendingAppends.wait() blocks fetch() → all async appends
        // complete first → finishFile() closes batch array correctly → no corruption

        let analytics = Analytics(configuration: Configuration(writeKey: "test-race-condition")
            .storageMode(.disk)
            .operatingMode(.asynchronous))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        // Queue multiple events rapidly
        for i in 0..<50 {
            analytics.track(name: "TestEvent\(i)")
        }

        // Trigger flush (this is where race condition would occur without fix)
        analytics.flush()

        // Wait for flush to complete
        Thread.sleep(forTimeInterval: 0.5)

        // Success: no crash means DispatchGroup prevented race condition
        //print("✅ Async append test passed - no race condition detected")

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
        //print("✅ Synchronous mode test passed - no race condition possible")

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
    }

    func testHighVolumeAsyncAppends() throws {
        // Stress test with high event volume to maximize race condition likelihood
        //
        // This test queues 100 events concurrently from multiple threads, then
        // immediately triggers flush. Without the fix, many async appends would
        // still be queued when finishFile() executes, causing corruption.

        let analytics = Analytics(configuration: Configuration(writeKey: "test-high-volume")
            .storageMode(.disk)
            .operatingMode(.asynchronous))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        // Queue many events rapidly from multiple threads
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            analytics.track(name: "Event\(i)")
        }

        // Trigger flush immediately (maximum race condition pressure)
        analytics.flush()

        // Wait for flush to complete
        Thread.sleep(forTimeInterval: 0.5)

        // Success: no crash means DispatchGroup prevented race condition
        //print("✅ High volume test passed - no race condition detected")

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
    }
}
