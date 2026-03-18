import XCTest
@testable import Segment

class Storage_RetryState_Tests: XCTestCase {
    var storage: Storage!

    func uniqueWriteKey() -> String {
        return "test-\(UUID().uuidString)"
    }

    override func setUp() {
        super.setUp()
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        storage = analytics.storage
    }

    override func tearDown() {
        // Clean up
        storage.hardReset(doYouKnowHowToUseThis: true)
        super.tearDown()
    }

    func testSaveAndLoadRetryState() {
        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: 12345.0,
            globalRetryCount: 3,
            batchMetadata: ["batch1": BatchMetadata(failureCount: 2)]
        )

        storage.saveRetryState(state)
        let loaded = storage.loadRetryState()

        XCTAssertEqual(loaded.pipelineState, .rateLimited)
        XCTAssertEqual(loaded.waitUntilTime, 12345.0)
        XCTAssertEqual(loaded.globalRetryCount, 3)
        XCTAssertEqual(loaded.batchMetadata.count, 1)
    }

    func testLoadRetryStateReturnsDefaultsWhenMissing() {
        let loaded = storage.loadRetryState()

        XCTAssertEqual(loaded.pipelineState, .ready)
        XCTAssertNil(loaded.waitUntilTime)
        XCTAssertEqual(loaded.globalRetryCount, 0)
        XCTAssertTrue(loaded.batchMetadata.isEmpty)
    }

    func testSaveRetryState_WithEmptyBatchMetadata() {
        let state = RetryState(
            pipelineState: .ready,
            waitUntilTime: nil,
            globalRetryCount: 0,
            batchMetadata: [:]
        )

        storage.saveRetryState(state)
        let loaded = storage.loadRetryState()

        XCTAssertEqual(loaded.pipelineState, .ready)
        XCTAssertTrue(loaded.batchMetadata.isEmpty)
    }

    func testSaveRetryState_WithMultipleBatchMetadataEntries() {
        let state = RetryState(
            batchMetadata: [
                "batch1": BatchMetadata(failureCount: 1, nextRetryTime: 1000, firstFailureTime: 100),
                "batch2": BatchMetadata(failureCount: 2, nextRetryTime: 2000, firstFailureTime: 200),
                "batch3": BatchMetadata(failureCount: 3, nextRetryTime: 3000, firstFailureTime: 300)
            ]
        )

        storage.saveRetryState(state)
        let loaded = storage.loadRetryState()

        XCTAssertEqual(loaded.batchMetadata.count, 3)
        XCTAssertEqual(loaded.batchMetadata["batch1"]?.failureCount, 1)
        XCTAssertEqual(loaded.batchMetadata["batch2"]?.failureCount, 2)
        XCTAssertEqual(loaded.batchMetadata["batch3"]?.failureCount, 3)
    }

    func testSaveRetryState_OverwritesPreviousState() {
        // Save initial state
        let state1 = RetryState(globalRetryCount: 5)
        storage.saveRetryState(state1)

        // Overwrite with new state
        let state2 = RetryState(globalRetryCount: 10)
        storage.saveRetryState(state2)

        // Should load the newer state
        let loaded = storage.loadRetryState()
        XCTAssertEqual(loaded.globalRetryCount, 10)
    }

    func testLoadRetryState_HandlesNullWaitUntilTime() {
        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: nil
        )

        storage.saveRetryState(state)
        let loaded = storage.loadRetryState()

        XCTAssertEqual(loaded.pipelineState, .rateLimited)
        XCTAssertNil(loaded.waitUntilTime)
    }

    func testLoadRetryState_HandlesNullFieldsInBatchMetadata() {
        let state = RetryState(
            batchMetadata: [
                "batch1": BatchMetadata(
                    failureCount: 1,
                    nextRetryTime: nil,
                    firstFailureTime: nil
                )
            ]
        )

        storage.saveRetryState(state)
        let loaded = storage.loadRetryState()

        let batch = loaded.batchMetadata["batch1"]
        XCTAssertNotNil(batch)
        XCTAssertEqual(batch?.failureCount, 1)
        XCTAssertNil(batch?.nextRetryTime)
        XCTAssertNil(batch?.firstFailureTime)
    }
}
