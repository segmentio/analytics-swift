import XCTest
@testable import Segment

class RetryChain_Tests: XCTestCase {
    var config: HttpConfig!
    var timeProvider: FakeTimeProvider!
    var stateMachine: RetryStateMachine!

    override func setUp() {
        super.setUp()
        config = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(enabled: true)
        )
        timeProvider = FakeTimeProvider(currentTime: 1000)
        stateMachine = RetryStateMachine(config: config, timeProvider: timeProvider)
    }

    func testChain_429_429_200() {
        var state = RetryState()

        // Attempt 1: 429 with 30s retry-after
        let response1 = ResponseInfo(
            statusCode: 429,
            retryAfterSeconds: 30,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )
        state = stateMachine.handleResponse(state: state, response: response1)

        // Verify: Rate limited
        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1030) // 1000 + 30

        // Try to upload while rate limited - should skip
        let (decision1, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch2")
        if case .skipAllBatches = decision1 {
            XCTAssert(true)
        } else {
            XCTFail("Should skip all batches while rate limited")
        }

        // Advance time past first rate limit (31s)
        timeProvider.advance(by: 31)

        // Attempt 2: 429 again with another 30s retry-after
        let response2 = ResponseInfo(
            statusCode: 429,
            retryAfterSeconds: 30,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )
        state = stateMachine.handleResponse(state: state, response: response2)

        // Verify: Still rate limited with new wait time
        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1031 + 30) // new time + 30
        XCTAssertEqual(state.globalRetryCount, 2)

        // Advance time past second rate limit (31s more)
        timeProvider.advance(by: 31)

        // Attempt 3: 200 success
        let response3 = ResponseInfo(
            statusCode: 200,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )
        state = stateMachine.handleResponse(state: state, response: response3)

        // Verify: Back to ready state
        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertNil(state.waitUntilTime)
        XCTAssertEqual(state.globalRetryCount, 0)

        // Should now allow uploads
        let (decision2, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch2")
        if case .proceed = decision2 {
            XCTAssert(true)
        } else {
            XCTFail("Should proceed after successful response")
        }
    }

    func testChain_500_500_200() {
        var state = RetryState()

        // Attempt 1: 500 error
        let response1 = ResponseInfo(
            statusCode: 500,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )
        state = stateMachine.handleResponse(state: state, response: response1)

        // Verify: Batch metadata created
        XCTAssertEqual(state.batchMetadata.count, 1)
        let metadata1 = state.batchMetadata["batch1"]!
        XCTAssertEqual(metadata1.failureCount, 1)
        XCTAssertNotNil(metadata1.nextRetryTime)

        // Try to upload before backoff expires - should skip this batch
        let (decision1, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch1")
        if case .skipThisBatch = decision1 {
            XCTAssert(true)
        } else {
            XCTFail("Should skip batch during backoff")
        }

        // Advance past backoff time
        let backoffTime = metadata1.nextRetryTime!
        timeProvider.setTime(backoffTime + 1)

        // Attempt 2: 500 again
        let response2 = ResponseInfo(
            statusCode: 500,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )
        state = stateMachine.handleResponse(state: state, response: response2)

        // Verify: Failure count incremented
        let metadata2 = state.batchMetadata["batch1"]!
        XCTAssertEqual(metadata2.failureCount, 2)

        // Advance past second backoff
        let backoffTime2 = metadata2.nextRetryTime!
        timeProvider.setTime(backoffTime2 + 1)

        // Attempt 3: 200 success
        let response3 = ResponseInfo(
            statusCode: 200,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )
        state = stateMachine.handleResponse(state: state, response: response3)

        // Verify: Metadata cleared
        XCTAssertTrue(state.batchMetadata.isEmpty)

        // Should allow upload
        let (decision2, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch1")
        if case .proceed = decision2 {
            XCTAssert(true)
        } else {
            XCTFail("Should proceed after successful response")
        }
    }
}
