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
}
