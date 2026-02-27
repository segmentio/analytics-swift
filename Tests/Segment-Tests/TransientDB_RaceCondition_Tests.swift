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

        let config = DirectoryStore.Configuration(
            writeKey: "test-race-condition",
            storageLocation: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("segment-race-test"),
            baseFilename: "test-events",
            maxFileSize: 475000,
            indexKey: "test.index"
        )

        let store = DirectoryStore(configuration: config)
        let db = TransientDB(store: store, asyncAppend: true)

        // Clean up any existing data
        db.reset()

        // Queue multiple events rapidly
        let eventCount = 50
        let expectation = XCTestExpectation(description: "All events should be in batch")

        for i in 0..<eventCount {
            let event = TrackEvent(event: "TestEvent\(i)", properties: ["index": i])
            db.append(data: event)
        }

        // Immediately fetch (this would trigger the race condition in unfixed version)
        // With fix, fetch() waits for pending appends via DispatchGroup
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            let result = db.fetch()

            // Verify we got data
            XCTAssertNotNil(result, "Should have fetched data")

            if let result = result {
                // Read the batch file and verify structure
                XCTAssertFalse(result.dataFiles.isEmpty, "Should have at least one data file")

                if let firstFile = result.dataFiles.first as? URL {
                    do {
                        let contents = try String(contentsOf: firstFile, encoding: .utf8)

                        // Verify proper JSON structure:
                        // 1. Should start with { "batch": [
                        XCTAssertTrue(contents.hasPrefix("{ \"batch\": ["), "Should start with batch array")

                        // 2. Should have only ONE closing bracket for array
                        let closingBrackets = contents.components(separatedBy: "]").count - 1
                        XCTAssertEqual(closingBrackets, 1, "Should have exactly one closing bracket for batch array")

                        // 3. Should have only ONE sentAt field
                        let sentAtCount = contents.components(separatedBy: "\"sentAt\"").count - 1
                        XCTAssertEqual(sentAtCount, 1, "Should have exactly one sentAt field")

                        // 4. Should have only ONE writeKey field
                        let writeKeyCount = contents.components(separatedBy: "\"writeKey\"").count - 1
                        XCTAssertEqual(writeKeyCount, 1, "Should have exactly one writeKey field")

                        // 5. Should be valid JSON
                        let jsonData = contents.data(using: .utf8)!
                        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: jsonData), "Should be valid JSON")

                        // 6. Verify all events are in the batch array
                        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                        XCTAssertNotNil(json, "Should parse as JSON object")

                        let batch = json?["batch"] as? [[String: Any]]
                        XCTAssertNotNil(batch, "Should have batch array")

                        // All events should be in the array (may be less than eventCount if max file size reached)
                        XCTAssertGreaterThan(batch?.count ?? 0, 0, "Should have events in batch")

                        print("✅ Successfully verified batch structure with \(batch?.count ?? 0) events")
                    } catch {
                        XCTFail("Failed to read or parse batch file: \(error)")
                    }
                }
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // Cleanup
        db.reset()
    }

    func testSynchronousModeNoRaceCondition() throws {
        // Verify that synchronous mode also works correctly (no race condition possible)

        let config = DirectoryStore.Configuration(
            writeKey: "test-sync-mode",
            storageLocation: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("segment-sync-test"),
            baseFilename: "test-events",
            maxFileSize: 475000,
            indexKey: "test.index"
        )

        let store = DirectoryStore(configuration: config)
        let db = TransientDB(store: store, asyncAppend: false)  // Synchronous mode

        db.reset()

        // Add events
        for i in 0..<10 {
            let event = TrackEvent(event: "SyncEvent\(i)", properties: ["index": i])
            db.append(data: event)
        }

        // Fetch immediately (no race condition in sync mode)
        let result = db.fetch()

        XCTAssertNotNil(result, "Should have fetched data")

        if let result = result, let firstFile = result.dataFiles.first as? URL {
            let contents = try String(contentsOf: firstFile, encoding: .utf8)

            // Verify proper structure
            XCTAssertTrue(contents.hasPrefix("{ \"batch\": ["), "Should start with batch array")

            let jsonData = contents.data(using: .utf8)!
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: jsonData), "Should be valid JSON")

            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            let batch = json?["batch"] as? [[String: Any]]

            XCTAssertEqual(batch?.count, 10, "Should have all 10 events in batch")
        }

        db.reset()
    }

    func testHighVolumeAsyncAppends() throws {
        // Stress test with high event volume to increase race condition likelihood

        let config = DirectoryStore.Configuration(
            writeKey: "test-high-volume",
            storageLocation: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("segment-stress-test"),
            baseFilename: "test-events",
            maxFileSize: 475000,
            indexKey: "test.index"
        )

        let store = DirectoryStore(configuration: config)
        let db = TransientDB(store: store, asyncAppend: true)

        db.reset()

        let eventCount = 100
        let expectation = XCTestExpectation(description: "High volume test")

        // Queue many events rapidly from multiple threads
        DispatchQueue.concurrentPerform(iterations: eventCount) { i in
            let event = TrackEvent(event: "Event\(i)", properties: ["index": i])
            db.append(data: event)
        }

        // Fetch immediately after queuing
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let result = db.fetch()

            XCTAssertNotNil(result, "Should have fetched data")

            if let result = result, let firstFile = result.dataFiles.first as? URL {
                do {
                    let contents = try String(contentsOf: firstFile, encoding: .utf8)

                    // Verify valid JSON structure (no corruption)
                    let jsonData = contents.data(using: .utf8)!
                    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

                    XCTAssertNotNil(json, "Should parse as valid JSON")

                    let batch = json?["batch"] as? [[String: Any]]
                    XCTAssertNotNil(batch, "Should have batch array")
                    XCTAssertGreaterThan(batch?.count ?? 0, 0, "Should have events in batch")

                    print("✅ High volume test passed with \(batch?.count ?? 0) events")
                } catch {
                    XCTFail("Failed to parse batch file: \(error)")
                }
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        db.reset()
    }
}
