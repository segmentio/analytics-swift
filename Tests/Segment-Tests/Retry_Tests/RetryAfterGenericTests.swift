import XCTest
@testable import Segment

class RetryAfterGenericTests: XCTestCase {
    var config: HttpConfig!
    var timeProvider: FakeTimeProvider!
    var stateMachine: RetryStateMachine!

    override func setUp() {
        super.setUp()
        config = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true, maxRetryCount: 100, maxRetryInterval: 300),
            backoffConfig: BackoffConfig(enabled: true, maxRetryCount: 100, baseBackoffInterval: 0.5,
                                        maxBackoffInterval: 300, maxTotalBackoffDuration: 43200, jitterPercent: 1)
        )
        timeProvider = FakeTimeProvider(currentTime: 1000)
        stateMachine = RetryStateMachine(config: config, timeProvider: timeProvider)
    }

    // 529 + Retry-After:30 → pipelineState=.rateLimited, waitUntilTime=1030, globalRetryCount=1, batchMetadata nil
    func test_529_withRetryAfter_triggersPipelinePause() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 529, retryAfterSeconds: 30, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1030.0)
        XCTAssertEqual(state.globalRetryCount, 1)
        XCTAssertNil(state.batchMetadata["batch1"])
    }

    // 529 + Retry-After:30 → batchMetadata nil (free retry, no failureCount)
    func test_529_withRetryAfter_doesNotIncrementFailureCount() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 529, retryAfterSeconds: 30, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertNil(state.batchMetadata["batch1"])
    }

    // 503 + Retry-After:60 → pipeline-pause, waitUntilTime=1060
    func test_503_withRetryAfter_triggersPipelinePause() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 503, retryAfterSeconds: 60, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1060.0)
        XCTAssertEqual(state.globalRetryCount, 1)
        XCTAssertNil(state.batchMetadata["batch1"])
    }

    // 408 + Retry-After:10 → pipeline-pause, waitUntilTime=1010
    func test_408_withRetryAfter_triggersPipelinePause() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 408, retryAfterSeconds: 10, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1010.0)
        XCTAssertEqual(state.globalRetryCount, 1)
        XCTAssertNil(state.batchMetadata["batch1"])
    }

    // 529 + no Retry-After → falls into exponential backoff
    func test_529_withoutRetryAfter_usesExponentialBackoff() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 529, retryAfterSeconds: nil, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertNil(state.waitUntilTime)
        XCTAssertEqual(state.globalRetryCount, 0)
        XCTAssertNotNil(state.batchMetadata["batch1"])
        XCTAssertEqual(state.batchMetadata["batch1"]?.failureCount, 1)
    }

    // 503 + no Retry-After → falls into backoff path
    func test_503_withoutRetryAfter_usesExponentialBackoff() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 503, retryAfterSeconds: nil, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertNil(state.waitUntilTime)
        XCTAssertEqual(state.globalRetryCount, 0)
        XCTAssertNotNil(state.batchMetadata["batch1"])
        XCTAssertEqual(state.batchMetadata["batch1"]?.failureCount, 1)
    }

    // 529 + Retry-After:99999 → waitUntilTime=1300 (clamped to maxRetryInterval=300)
    func test_retryAfter_clampedAtMaxRetryInterval() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 529, retryAfterSeconds: 99999, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1300.0)
    }

    // 529 + Retry-After:0 → pipelineState=.rateLimited, waitUntilTime=1000
    func test_retryAfterZero_usesZeroWait() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 529, retryAfterSeconds: 0, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1000.0)
    }

    // 3 rate-limit responses → shouldUploadBatch returns dropBatch after cap
    func test_globalRetryCountCapDropsBatchAfterMaxRetries() {
        let cappedConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true, maxRetryCount: 3, maxRetryInterval: 300),
            backoffConfig: BackoffConfig(enabled: true, maxRetryCount: 100, baseBackoffInterval: 0.5,
                                        maxBackoffInterval: 300, maxTotalBackoffDuration: 43200, jitterPercent: 1)
        )
        let machine = RetryStateMachine(config: cappedConfig, timeProvider: timeProvider)
        var state = RetryState()

        for _ in 1...3 {
            let response = ResponseInfo(statusCode: 529, retryAfterSeconds: 30, batchFile: "batch1", currentTime: 1000.0)
            state = machine.handleResponse(state: state, response: response)
        }

        XCTAssertEqual(state.globalRetryCount, 3)
        timeProvider.setTime(2000.0)

        let (decision, _) = machine.shouldUploadBatch(state: state, batchFile: "batch1")
        if case .dropBatch(let reason) = decision {
            XCTAssertEqual(reason, .maxRetriesExceeded)
        } else {
            XCTFail("Expected dropBatch(reason: .maxRetriesExceeded), got \(decision)")
        }
    }

    // 400 + Retry-After:60 → non-retryable, drops immediately
    func test_400_withRetryAfter_dropsImmediately() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 400, retryAfterSeconds: 60, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertNil(state.batchMetadata["batch1"])
        XCTAssertNil(state.waitUntilTime)
        XCTAssertEqual(state.globalRetryCount, 0)
    }

    // Regression guard: 429 + Retry-After:45 → unchanged behavior
    func test_429_behaviorUnchanged() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 429, retryAfterSeconds: 45, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1045.0)
        XCTAssertEqual(state.globalRetryCount, 1)
    }

    // 529 + Retry-After pause holds ALL batches, not just the triggering one
    func test_pipelinePause_holdsAllBatches() {
        var state = RetryState()
        let response = ResponseInfo(statusCode: 529, retryAfterSeconds: 30, batchFile: "batch1", currentTime: 1000.0)
        state = stateMachine.handleResponse(state: state, response: response)

        let (decision1, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch1")
        let (decision2, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch2")

        if case .skipAllBatches = decision1 { } else {
            XCTFail("Expected skipAllBatches for batch1, got \(decision1)")
        }
        if case .skipAllBatches = decision2 { } else {
            XCTFail("Expected skipAllBatches for batch2, got \(decision2)")
        }
    }
}
