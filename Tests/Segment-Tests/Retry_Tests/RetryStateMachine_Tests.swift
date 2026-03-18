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

    func testShouldUploadBatch_RateLimitedBlocksAll() {
        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: timeProvider.now() + 60
        )

        let (decision, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch1")

        if case .skipAllBatches = decision {
            XCTAssert(true)
        } else {
            XCTFail("Expected skipAllBatches, got \(decision)")
        }
    }

    func testShouldUploadBatch_BackoffNotReadySkipsBatch() {
        let futureRetryTime = timeProvider.now() + 30
        let metadata = BatchMetadata(
            failureCount: 1,
            nextRetryTime: futureRetryTime
        )
        let state = RetryState(batchMetadata: ["batch1": metadata])

        let (decision, _) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch1")

        if case .skipThisBatch = decision {
            XCTAssert(true)
        } else {
            XCTFail("Expected skipThisBatch, got \(decision)")
        }
    }

    // MARK: - Status Code Behavior Tests

    func test4xxCodesDefaultToDrop() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 400,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertFalse(state.batchMetadata.keys.contains("batch1"))
        XCTAssertEqual(state.pipelineState, .ready)
    }

    func test408OverridesDefault4xxBehaviorAndRetries() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 408,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertTrue(state.batchMetadata.keys.contains("batch1"))
        XCTAssertEqual(state.batchMetadata["batch1"]?.failureCount, 1)
    }

    func test5xxCodesDefaultToRetry() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 503,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertTrue(state.batchMetadata.keys.contains("batch1"))
        XCTAssertEqual(state.batchMetadata["batch1"]?.failureCount, 1)
    }

    func test501OverridesDefault5xxBehaviorAndDrops() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 501,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertFalse(state.batchMetadata.keys.contains("batch1"))
    }

    func testUnknownCodesUseUnknownCodeBehavior() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 666,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )

        state = stateMachine.handleResponse(state: state, response: response)

        // Default unknownCodeBehavior is DROP
        XCTAssertFalse(state.batchMetadata.keys.contains("batch1"))
    }

    // MARK: - Exponential Backoff Tests

    func testExponentialBackoffIncreasesCorrectly() {
        var state = RetryState()

        // First failure: baseBackoffInterval * 2^0 = 0.5s (with jitter)
        let response1 = ResponseInfo(
            statusCode: 503,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: 1000
        )
        state = stateMachine.handleResponse(state: state, response: response1)

        var metadata = state.batchMetadata["batch1"]!
        XCTAssertEqual(metadata.failureCount, 1)
        XCTAssertNotNil(metadata.nextRetryTime)
        // Should be around 1000 + 500ms, with up to 10% jitter = 1450-1550
        XCTAssertTrue(metadata.nextRetryTime! >= 1000.45 && metadata.nextRetryTime! <= 1000.55)
        XCTAssertEqual(metadata.firstFailureTime, 1000)

        // Second failure: baseBackoffInterval * 2^1 = 1.0s (with jitter)
        timeProvider.setTime(metadata.nextRetryTime!)
        let response2 = ResponseInfo(
            statusCode: 503,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: timeProvider.now()
        )
        state = stateMachine.handleResponse(state: state, response: response2)

        metadata = state.batchMetadata["batch1"]!
        XCTAssertEqual(metadata.failureCount, 2)
        XCTAssertTrue(metadata.nextRetryTime! > timeProvider.now() + 0.9)
        XCTAssertEqual(metadata.firstFailureTime, 1000) // Should not change
    }

    // MARK: - Rate Limit Tests

    func test429ClampsExcessiveRetryAfterToMaxRetryInterval() {
        var state = RetryState()

        // Retry-After=500 seconds, but maxRetryInterval=300
        let response = ResponseInfo(
            statusCode: 429,
            retryAfterSeconds: 500,
            batchFile: "batch1",
            currentTime: 1000
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .rateLimited)
        XCTAssertEqual(state.waitUntilTime, 1300) // 1000 + 300 (clamped)
    }

    func test429UsesMaxRetryIntervalWhenRetryAfterIsMissing() {
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 429,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: 1000
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.waitUntilTime, 1300) // defaults to 300s
    }

    func testGlobalRetryCountResetsOnSuccessfulUpload() {
        var state = RetryState(
            globalRetryCount: 5,
            batchMetadata: ["batch1": BatchMetadata(failureCount: 3)]
        )

        let response = ResponseInfo(
            statusCode: 200,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: 1000
        )

        state = stateMachine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.globalRetryCount, 0)
        XCTAssertFalse(state.batchMetadata.keys.contains("batch1"))
    }

    // MARK: - shouldUploadBatch Edge Cases

    func testShouldUploadBatch_ProceedsWhenRateLimitTimePasses() {
        let rateLimitedState = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: 1060
        )

        timeProvider.setTime(1061) // After waitUntilTime

        let (decision, _) = stateMachine.shouldUploadBatch(state: rateLimitedState, batchFile: "batch1")

        if case .proceed = decision {
            XCTAssert(true)
        } else {
            XCTFail("Expected proceed, got \(decision)")
        }
    }

    func testShouldUploadBatch_DropsBatchAfterMaxRetries() {
        let metadata = BatchMetadata(
            failureCount: 100, // At max
            nextRetryTime: 1000,
            firstFailureTime: 1000
        )
        let state = RetryState(batchMetadata: ["batch1": metadata])

        timeProvider.setTime(2000)

        let (decision, newState) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch1")

        if case .dropBatch(let reason) = decision {
            XCTAssertEqual(reason, .maxRetriesExceeded)
        } else {
            XCTFail("Expected dropBatch, got \(decision)")
        }
        XCTAssertFalse(newState.batchMetadata.keys.contains("batch1"))
    }

    func testShouldUploadBatch_DropsBatchAfterMaxDuration() {
        let metadata = BatchMetadata(
            failureCount: 5,
            nextRetryTime: 1000,
            firstFailureTime: 1000
        )
        let state = RetryState(batchMetadata: ["batch1": metadata])

        // Advance past max duration (12 hours = 43200 seconds)
        timeProvider.setTime(1000 + 43200 + 1)

        let (decision, newState) = stateMachine.shouldUploadBatch(state: state, batchFile: "batch1")

        if case .dropBatch(let reason) = decision {
            XCTAssertEqual(reason, .maxDurationExceeded)
        } else {
            XCTFail("Expected dropBatch, got \(decision)")
        }
        XCTAssertFalse(newState.batchMetadata.keys.contains("batch1"))
    }

    // MARK: - getRetryCount Tests

    func testGetRetryCount_ReturnsZeroForNewBatch() {
        let state = RetryState()

        let retryCount = stateMachine.getRetryCount(state: state, batchFile: "batch1")

        XCTAssertEqual(retryCount, 0)
    }

    func testGetRetryCount_ReturnsPerBatchFailureCount() {
        let state = RetryState(
            batchMetadata: ["batch1": BatchMetadata(failureCount: 3)]
        )

        let retryCount = stateMachine.getRetryCount(state: state, batchFile: "batch1")

        XCTAssertEqual(retryCount, 3)
    }

    func testGetRetryCount_ReturnsMaxOfPerBatchAndGlobalCount() {
        let state = RetryState(
            globalRetryCount: 10,
            batchMetadata: ["batch1": BatchMetadata(failureCount: 3)]
        )

        let retryCount = stateMachine.getRetryCount(state: state, batchFile: "batch1")

        XCTAssertEqual(retryCount, 10) // max(3, 10)
    }

    func testGetRetryCount_ReturnsGlobalCountWhenNoBatchMetadata() {
        let state = RetryState(globalRetryCount: 5)

        let retryCount = stateMachine.getRetryCount(state: state, batchFile: "batch1")

        XCTAssertEqual(retryCount, 5)
    }

    // MARK: - Legacy Mode Tests

    func testLegacyMode_429DoesNotTriggerRateLimiting() {
        let disabledConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: false),
            backoffConfig: BackoffConfig(enabled: false)
        )
        let machine = RetryStateMachine(config: disabledConfig, timeProvider: timeProvider)
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 429,
            retryAfterSeconds: 60,
            batchFile: "batch1",
            currentTime: 1000
        )

        state = machine.handleResponse(state: state, response: response)

        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertFalse(state.batchMetadata.keys.contains("batch1"))
    }

    func testLegacyMode_5xxDoesNotCreateMetadata() {
        let disabledConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: false),
            backoffConfig: BackoffConfig(enabled: false)
        )
        let machine = RetryStateMachine(config: disabledConfig, timeProvider: timeProvider)
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 503,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: 1000
        )

        state = machine.handleResponse(state: state, response: response)

        XCTAssertFalse(state.batchMetadata.keys.contains("batch1"))
    }

    func testLegacyMode_4xxDropsBatch() {
        let disabledConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: false),
            backoffConfig: BackoffConfig(enabled: false)
        )
        let machine = RetryStateMachine(config: disabledConfig, timeProvider: timeProvider)
        var state = RetryState()

        let response = ResponseInfo(
            statusCode: 400,
            retryAfterSeconds: nil,
            batchFile: "batch1",
            currentTime: 1000
        )

        state = machine.handleResponse(state: state, response: response)

        XCTAssertFalse(state.batchMetadata.keys.contains("batch1"))
    }

    func testLegacyMode_ShouldUploadBatchAlwaysProceeds() {
        let disabledConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: false),
            backoffConfig: BackoffConfig(enabled: false)
        )
        let machine = RetryStateMachine(config: disabledConfig, timeProvider: timeProvider)
        let state = RetryState()

        let (decision, _) = machine.shouldUploadBatch(state: state, batchFile: "any-batch")

        if case .proceed = decision {
            XCTAssert(true)
        } else {
            XCTFail("Expected proceed in legacy mode, got \(decision)")
        }
    }
}
