#if !os(Linux) && !os(Windows)

import XCTest
@testable import Segment

// MARK: - Mock HTTP session with configurable responses

private class MockTask: UploadTask, DataTask {
    var state: URLSessionTask.State = .completed
    func resume() {}
}

private class ConfigurableHTTPSession: HTTPSession {
    /// Status code returned by upload calls
    var uploadStatusCode: Int = 200
    /// Extra headers on upload responses (e.g. Retry-After)
    var uploadHeaders: [String: String] = [:]
    /// When true, upload returns a network error instead of an HTTP response
    var shouldError: Bool = false
    /// Tracks upload requests (data uploads)
    var dataUploadCount: Int = 0
    /// Tracks captured X-Retry-Count header values
    var capturedRetryCountHeaders: [String?] = []

    func uploadTask(with request: URLRequest, fromFile file: URL,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> MockTask {
        let task = MockTask()
        let statusCode = uploadStatusCode
        let headers = uploadHeaders
        let error = shouldError
        capturedRetryCountHeaders.append(request.value(forHTTPHeaderField: "X-Retry-Count"))
        DispatchQueue.global().async {
            if error {
                completionHandler(nil, nil, NSError(domain: "test", code: -1))
            } else {
                let resp = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: headers)
                completionHandler(nil, resp, nil)
            }
        }
        return task
    }

    func uploadTask(with request: URLRequest, from bodyData: Data?,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> MockTask {
        dataUploadCount += 1
        let task = MockTask()
        let statusCode = uploadStatusCode
        let headers = uploadHeaders
        let error = shouldError
        capturedRetryCountHeaders.append(request.value(forHTTPHeaderField: "X-Retry-Count"))
        DispatchQueue.global().async {
            if error {
                completionHandler(nil, nil, NSError(domain: "test", code: -1))
            } else {
                let resp = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: headers)
                completionHandler(nil, resp, nil)
            }
        }
        return task
    }

    func dataTask(with request: URLRequest,
                  completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> MockTask {
        let task = MockTask()
        // Settings requests — always succeed
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

// MARK: - Helper to create memory-mode analytics with configurable session

private func makeMemoryAnalytics(
    session: ConfigurableHTTPSession,
    httpConfig: HttpConfig? = nil,
    flushAt: Int = 1
) -> Analytics {
    var config = Configuration(writeKey: uniqueWriteKey())
        .flushInterval(9999)
        .flushAt(flushAt)
        .operatingMode(.synchronous)
        .storageMode(.memory(100))
        .httpSession(session)

    if let httpConfig = httpConfig {
        config = config.httpConfig(httpConfig)
    }

    let analytics = Analytics(configuration: config)
    waitUntilStarted(analytics: analytics)
    return analytics
}

// MARK: - Tests

class FlushData_Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        Telemetry.shared.enable = false
    }

    // MARK: CDN httpConfig parsing (SegmentDestination lines 83-96)

    func testUpdateSettingsWithHttpConfigRebuildsHTTPClient() {
        let session = ConfigurableHTTPSession()
        let analytics = makeMemoryAnalytics(session: session)

        let segment = analytics.find(pluginType: SegmentDestination.self)!
        let originalClient = segment.httpClient

        // Construct settings with httpConfig in integrations
        let settingsJSON = """
        {
            "integrations": {
                "Segment.io": {
                    "apiKey": "test",
                    "httpConfig": {
                        "rateLimitConfig": { "enabled": true, "maxRetryCount": 10 },
                        "backoffConfig": { "enabled": true, "maxRetryCount": 5 }
                    }
                }
            },
            "plan": { "track": { "__default": { "enabled": true } } }
        }
        """.data(using: .utf8)!

        let settings = try! JSONDecoder.default.decode(Settings.self, from: settingsJSON)
        segment.update(settings: settings, type: .initial)

        // HTTPClient should have been rebuilt
        XCTAssertFalse(segment.httpClient === originalClient)
    }

    // MARK: flushData batch isolation (SegmentDestination lines 252-264)

    func testFlushDataDropsBatchWhenMaxRetriesExceeded() {
        let session = ConfigurableHTTPSession()
        session.uploadStatusCode = 500

        let httpConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(
                enabled: true,
                maxRetryCount: 1,
                baseBackoffInterval: 0.1
            )
        )

        let analytics = makeMemoryAnalytics(session: session, httpConfig: httpConfig, flushAt: 9999)
        analytics.track(name: "drop-test-event")

        // First flush: 500 → retry state records failure (count=1)
        let flush1 = XCTestExpectation(description: "flush 1")
        analytics.flush { flush1.fulfill() }
        wait(for: [flush1], timeout: 5)

        // Second flush: checkBatchUpload sees failureCount >= maxRetryCount → dropBatch
        // The batch should be dropped (removed from storage)
        let flush2 = XCTestExpectation(description: "flush 2")
        analytics.flush { flush2.fulfill() }
        wait(for: [flush2], timeout: 5)

        // After drop, storage should be empty
        XCTAssertFalse(analytics.storage.dataStore.hasData)
    }

    func testFlushDataSkipsBatchDuringBackoff() {
        let session = ConfigurableHTTPSession()
        session.uploadStatusCode = 500

        let httpConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(
                enabled: true,
                maxRetryCount: 100,       // won't hit drop
                baseBackoffInterval: 60.0  // long backoff so we're still in skip window
            )
        )

        let analytics = makeMemoryAnalytics(session: session, httpConfig: httpConfig, flushAt: 9999)
        analytics.track(name: "skip-test-event")

        // First flush: 500 → sets nextRetryTime = now + 60s
        let flush1 = XCTestExpectation(description: "flush 1")
        analytics.flush { flush1.fulfill() }
        wait(for: [flush1], timeout: 5)

        let uploadsBefore = session.dataUploadCount

        // Second flush: within backoff window → skipThisBatch, no upload attempted
        let flush2 = XCTestExpectation(description: "flush 2")
        analytics.flush { flush2.fulfill() }
        wait(for: [flush2], timeout: 5)

        // No new upload should have been attempted (skip)
        XCTAssertEqual(session.dataUploadCount, uploadsBefore)
        // Data should still be in storage (not removed)
        XCTAssertTrue(analytics.storage.dataStore.hasData)
    }

    // MARK: flushData nil upload task fallback (SegmentDestination lines 313-314)

    func testFlushDataHandlesNetworkError() {
        let session = ConfigurableHTTPSession()
        session.shouldError = true

        let httpConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(enabled: true)
        )

        let analytics = makeMemoryAnalytics(session: session, httpConfig: httpConfig, flushAt: 9999)
        analytics.track(name: "error-test-event")

        // Flush with network error — should not crash/hang
        let flush1 = XCTestExpectation(description: "flush 1")
        analytics.flush { flush1.fulfill() }
        wait(for: [flush1], timeout: 5)

        // Data stays in storage after network error
        XCTAssertTrue(analytics.storage.dataStore.hasData)
    }

    // MARK: HTTPClient handleResponse updates retry state (lines 163-170)
    // and extractRetryAfter (lines 151-152)

    func testRetryAfterHeaderUpdatesState() {
        let session = ConfigurableHTTPSession()
        session.uploadStatusCode = 429
        session.uploadHeaders = ["Retry-After": "30"]

        let httpConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true, maxRetryInterval: 300),
            backoffConfig: BackoffConfig(enabled: true)
        )

        let analytics = makeMemoryAnalytics(session: session, httpConfig: httpConfig, flushAt: 9999)
        analytics.track(name: "rate-limit-event")

        let flush1 = XCTestExpectation(description: "flush 1")
        analytics.flush { flush1.fulfill() }
        wait(for: [flush1], timeout: 5)

        // Data should still be in storage (429 is retryable)
        XCTAssertTrue(analytics.storage.dataStore.hasData)
    }

    // MARK: Retry succeeds on subsequent flush

    func testFlushDataRetriesAfterServerError() {
        let session = ConfigurableHTTPSession()
        session.uploadStatusCode = 500

        let httpConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(
                enabled: true,
                maxRetryCount: 100,
                baseBackoffInterval: 0.01
            )
        )

        let analytics = makeMemoryAnalytics(session: session, httpConfig: httpConfig, flushAt: 9999)
        analytics.track(name: "retry-event")

        // First flush: 500 → data stays
        analytics.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        XCTAssertTrue(analytics.storage.dataStore.hasData)
        XCTAssertEqual(session.dataUploadCount, 1)

        // Wait past backoff window before retrying
        Thread.sleep(forTimeInterval: 0.1)

        // Switch to success and retry
        session.uploadStatusCode = 200
        analytics.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))

        // Data should be delivered and removed
        XCTAssertFalse(analytics.storage.dataStore.hasData)
    }

    // MARK: Batch isolation — events don't cross-contaminate

    func testMemoryModeBatchIsolation() {
        let session = ConfigurableHTTPSession()
        // First upload fails, all subsequent succeed
        var callCount = 0
        // We'll track via the session's upload count
        session.uploadStatusCode = 500

        let httpConfig = HttpConfig(
            rateLimitConfig: RateLimitConfig(enabled: true),
            backoffConfig: BackoffConfig(
                enabled: true,
                maxRetryCount: 100,
                baseBackoffInterval: 0.01
            )
        )

        let analytics = makeMemoryAnalytics(session: session, httpConfig: httpConfig, flushAt: 1)

        // Queue first event — auto-flush will fail with 500
        analytics.track(name: "event-1")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        // Switch to 200 for subsequent
        session.uploadStatusCode = 200

        // Queue second event — should be batched separately from event-1
        analytics.track(name: "event-2")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        // Explicit flush to retry event-1
        Thread.sleep(forTimeInterval: 0.1) // past backoff
        let flush = XCTestExpectation(description: "final flush")
        analytics.flush { flush.fulfill() }
        wait(for: [flush], timeout: 5)

        // Both events should be delivered (storage empty)
        XCTAssertFalse(analytics.storage.dataStore.hasData)
        // At least 3 uploads: event-1 fail, event-2 success, event-1 retry success
        XCTAssertGreaterThanOrEqual(session.dataUploadCount, 3)
    }
}

#endif
