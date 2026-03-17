import XCTest
@testable import Segment

class RetryStateMachine_Tests: XCTestCase {
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

    func test200ResponseClearsBatchMetadata() {
        var state = RetryState(batchMetadata: ["batch1": BatchMetadata(failureCount: 2)])

        let response = ResponseInfo(
            statusCode: 200,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertTrue(state.batchMetadata.isEmpty)
        XCTAssertEqual(state.globalRetryCount, 0)
    }

    func test429SetsRateLimitedState() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 429,
            retryAfterSeconds: 60,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1000 + 60) // currentTime + 60 seconds
        XCTAssertEqual(state.globalRetryCount, 1)
    }

    func test500CreatesBackoffMetadata() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 500,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.batchMetadata.count, 1)
        let metadata = state.batchMetadata["batch1"]
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.failureCount, 1)
        XCTAssertNotNil(metadata?.nextRetryTime)
        XCTAssertEqual(metadata?.firstFailureTime, 1000)
    }
}
