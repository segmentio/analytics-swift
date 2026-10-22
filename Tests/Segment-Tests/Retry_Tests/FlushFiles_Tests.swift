#if !os(Linux) && !os(Windows)

import XCTest
@testable import Segment

// MARK: - Mock HTTP session with configurable responses

private class MockTask: UploadTask, DataTask {
    var state: URLSessionTask.State = .completed
    func resume() {}
}

private class ScriptedHTTPSession: HTTPSession {
    /// Status code returned by upload calls
    var uploadStatusCode: Int = 200
    /// Extra headers on upload responses (e.g. Retry-After)
    var uploadHeaders: [String: String] = [:]
    /// Tracks file upload requests that actually reached the session
    var fileUploadCount: Int = 0

    func uploadTask(with request: URLRequest, fromFile file: URL,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> MockTask {
        fileUploadCount += 1
        let task = MockTask()
        let resp = HTTPURLResponse(url: request.url!, statusCode: uploadStatusCode, httpVersion: nil, headerFields: uploadHeaders)
        DispatchQueue.global().async {
            completionHandler(nil, resp, nil)
        }
        return task
    }

    func uploadTask(with request: URLRequest, from bodyData: Data?,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> MockTask {
        let task = MockTask()
        let resp = HTTPURLResponse(url: request.url!, statusCode: uploadStatusCode, httpVersion: nil, headerFields: uploadHeaders)
        DispatchQueue.global().async {
            completionHandler(nil, resp, nil)
        }
        return task
    }

    func dataTask(with request: URLRequest,
                  completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> MockTask {
        let task = MockTask()
        DispatchQueue.global().async {
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            let settings = """
            {"integrations":{"Segment.io":{"apiKey":"test"}},"plan":{"track":{"__default":{"enabled":true}}}}
            """.data(using: .utf8)
            completionHandler(settings, resp, nil)
        }
        return task
    }

    func finishTasksAndInvalidate() {}
}

// MARK: - Tests

// Disk-mode flushes where the retry state machine skips or drops a batch.
// HTTPClient calls the completion synchronously and returns no task in those
// cases, so flushFiles must leave its DispatchGroup exactly once per batch.
class FlushFiles_Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        Telemetry.shared.enable = false
    }

    private func makeDiskAnalytics(session: ScriptedHTTPSession, httpConfig: HttpConfig) -> Analytics {
        let config = Configuration(writeKey: uniqueWriteKey())
            .flushInterval(9999)
            .flushAt(9999)
            .operatingMode(.synchronous)
            // own flush queue, so instances left over from other tests can't delay our flushes.
            .flushQueue(DispatchQueue(label: "com.segment.test.flushFiles"))
            .storageMode(.disk)
            .trackApplicationLifecycleEvents(false)
            .httpSession(session)
            .httpConfig(httpConfig)

        let analytics = Analytics(configuration: config)
        waitUntilStarted(analytics: analytics)
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        return analytics
    }

    private func flushAndWait(_ analytics: Analytics) {
        let flushed = expectation(description: "flush completed")
        analytics.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5.0)
    }

    private func pendingFiles(_ analytics: Analytics) -> Int {
        return analytics.storage.dataStore.fetch()?.dataFiles?.count ?? 0
    }

    func testFlushWhileRateLimitedSkipsBatchWithoutCrashing() {
        let session = ScriptedHTTPSession()
        session.uploadStatusCode = 429
        session.uploadHeaders = ["Retry-After": "60"]

        let analytics = makeDiskAnalytics(session: session, httpConfig: HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(enabled: true)
        ))

        // 429 + Retry-After puts the pipeline into the rate-limited state.
        analytics.track(name: "first")
        flushAndWait(analytics)
        XCTAssertEqual(session.fileUploadCount, 1)

        // While rate limited, the batch is skipped (.skipAllBatches) before upload.
        analytics.track(name: "second")
        flushAndWait(analytics)

        XCTAssertEqual(session.fileUploadCount, 1)
        XCTAssertGreaterThan(pendingFiles(analytics), 0)
    }

    func testFlushDuringBackoffSkipsBatchWithoutCrashing() {
        let session = ScriptedHTTPSession()
        session.uploadStatusCode = 500

        let analytics = makeDiskAnalytics(session: session, httpConfig: HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: false),
            backoffConfig: BackoffConfig(enabled: true, baseBackoffInterval: 60)
        ))

        // 500 records a failure and schedules a backoff for this batch.
        analytics.track(name: "first")
        flushAndWait(analytics)
        XCTAssertEqual(session.fileUploadCount, 1)

        // Within the backoff window the batch is skipped (.skipThisBatch).
        flushAndWait(analytics)

        XCTAssertEqual(session.fileUploadCount, 1)
        XCTAssertGreaterThan(pendingFiles(analytics), 0)
    }

    func testFlushAfterMaxRetriesDropsBatchWithoutCrashing() {
        let session = ScriptedHTTPSession()
        session.uploadStatusCode = 500

        let analytics = makeDiskAnalytics(session: session, httpConfig: HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: false),
            backoffConfig: BackoffConfig(enabled: true, maxRetryCount: 1, baseBackoffInterval: 0.1)
        ))

        analytics.track(name: "first")
        flushAndWait(analytics)
        XCTAssertEqual(session.fileUploadCount, 1)

        // Past the backoff, the retry limit is exhausted, so the batch is dropped (.dropBatch).
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        flushAndWait(analytics)

        XCTAssertEqual(session.fileUploadCount, 1)
        XCTAssertEqual(pendingFiles(analytics), 0)
    }

    func testFlushDropsRetryableBatchWhenBackoffDisabled() {
        let session = ScriptedHTTPSession()
        session.uploadStatusCode = 500

        // rate limiting stays on, as it does when settings only disable backoff.
        let analytics = makeDiskAnalytics(session: session, httpConfig: HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(enabled: false)
        ))

        // a 500 without Retry-After won't be retried by anything, so the batch is dropped.
        analytics.track(name: "first")
        flushAndWait(analytics)
        XCTAssertEqual(session.fileUploadCount, 1)
        XCTAssertEqual(pendingFiles(analytics), 0)

        flushAndWait(analytics)
        XCTAssertEqual(session.fileUploadCount, 1)
    }

    func testFlushKeepsRetryAfterBatchWhenBackoffDisabled() {
        let session = ScriptedHTTPSession()
        session.uploadStatusCode = 503
        session.uploadHeaders = ["Retry-After": "60"]

        let analytics = makeDiskAnalytics(session: session, httpConfig: HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(enabled: false)
        ))

        // Retry-After pauses the pipeline, and the batch waits for the pause to end.
        analytics.track(name: "first")
        flushAndWait(analytics)
        XCTAssertEqual(session.fileUploadCount, 1)
        XCTAssertGreaterThan(pendingFiles(analytics), 0)
    }
}

#endif
