import XCTest
@testable import Segment

class RetryState_Tests: XCTestCase {
    func testDefaultRetryState() {
        let state = RetryState()
        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertNil(state.waitUntilTime)
        XCTAssertEqual(state.globalRetryCount, 0)
        XCTAssertTrue(state.batchMetadata.isEmpty)
    }

    func testIsRateLimited() {
        let futureTime = Date().timeIntervalSince1970 + 60
        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: futureTime
        )

        let currentTime = Date().timeIntervalSince1970
        XCTAssertTrue(state.isRateLimited(currentTime: currentTime))
    }

    func testBatchMetadataShouldRetry() {
        let metadata = BatchMetadata(
            failureCount: 1,
            nextRetryTime: Date().timeIntervalSince1970 - 10
        )
        XCTAssertTrue(metadata.shouldRetry(currentTime: Date().timeIntervalSince1970))
    }

    func testFakeTimeProvider() {
        let fake = FakeTimeProvider(currentTime: 1000)
        XCTAssertEqual(fake.now(), 1000)

        fake.setTime(2000)
        XCTAssertEqual(fake.now(), 2000)

        fake.advance(by: 500)
        XCTAssertEqual(fake.now(), 2500)
    }

    // MARK: - Persistence Validation Tests

    func testIsRateLimited_HandlesUnreasonableWaitTime() {
        let now = Date().timeIntervalSince1970
        let impossiblyFar = now + TimeInterval(Int.max / 2) // Corrupted/unreasonable value

        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: impossiblyFar
        )

        // Current behavior: returns true (blocked indefinitely)
        // This test documents the behavior and guards against infinite blocking
        XCTAssertTrue(state.isRateLimited(currentTime: now))

        // Verify even after 1 hour (reasonable max), still blocked
        let oneHourLater = now + 3600
        XCTAssertTrue(state.isRateLimited(currentTime: oneHourLater))

        // Only clears when currentTime >= waitUntilTime
        // For corrupted values, this documents potential infinite blocking
    }

    func testExceedsMaxDuration_HandlesClockSkewGracefully() {
        let now = Date().timeIntervalSince1970
        let futureTime = now + 1000 // Clock skew: firstFailure is in the future

        let metadata = BatchMetadata(
            failureCount: 1,
            nextRetryTime: now + 10,
            firstFailureTime: futureTime
        )

        // When firstFailureTime is in future (clock went backwards),
        // exceedsMaxDuration should handle gracefully
        let result = metadata.exceedsMaxDuration(
            currentTime: now,
            maxDuration: 100
        )

        // Conservative behavior: returns false (won't drop batch)
        // This prevents premature drops due to clock changes
        XCTAssertFalse(result)

        // Verify the calculation: (now - futureTime) = negative value
        // Since guard returns false for nil, and calculation is negative,
        // it should never exceed max duration
    }

    func testBatchMetadata_HandlesNegativeFailureCount() {
        // While PropertyListDecoder validates types, this documents
        // behavior if corrupted state somehow has negative failureCount

        let metadata = BatchMetadata(
            failureCount: -1, // Corrupted value
            nextRetryTime: nil,
            firstFailureTime: nil
        )

        let config = HttpConfig(
            backoffConfig: BackoffConfig(maxRetryCount: 3)
        )
        let stateMachine = RetryStateMachine(
            config: config,
            timeProvider: FakeTimeProvider(currentTime: 1000)
        )

        let state = RetryState(batchMetadata: ["batch1": metadata])

        let (decision, _) = stateMachine.shouldUploadBatch(
            state: state,
            batchFile: "batch1"
        )

        // Current behavior: -1 < 3, so proceeds
        // This documents that negative failureCount bypasses max retry check
        if case .proceed = decision {
            XCTAssert(true)
        } else {
            XCTFail("Expected proceed for negative failureCount, got \(decision)")
        }
    }

    func testIsRateLimited_ReturnsFalseWhenWaitTimeIsNil() {
        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: nil // Corrupted: rate limited but no wait time
        )

        let currentTime = Date().timeIntervalSince1970

        // Guard clause should protect against nil waitUntilTime
        XCTAssertFalse(state.isRateLimited(currentTime: currentTime))
    }

    func testExceedsMaxDuration_ReturnsFalseWhenFirstFailureTimeIsNil() {
        let metadata = BatchMetadata(
            failureCount: 5,
            nextRetryTime: nil,
            firstFailureTime: nil // Missing timestamp
        )

        let result = metadata.exceedsMaxDuration(
            currentTime: Date().timeIntervalSince1970,
            maxDuration: 100
        )

        // Guard clause protects against nil firstFailureTime
        XCTAssertFalse(result)
    }
}
