#if !os(Linux) && !os(Windows)
import XCTest

@testable import Segment

class TelemetryTests: XCTestCase {
    var errors: [String] = []

    override func setUpWithError() throws {
        Telemetry.shared.reset()
        Telemetry.shared.errorHandler = { error in
            self.errors.append("\(error)")
        }
        errors.removeAll()
        Telemetry.shared.sampleRate = 1.0
        mockTelemetryHTTPClient()
    }

    override func tearDownWithError() throws {
        Telemetry.shared.reset()
    }

    func mockTelemetryHTTPClient(telemetryHost: String = Telemetry.shared.host, shouldThrow: Bool = false) {
        let sessionMock = URLSessionMock()
        if shouldThrow {
            sessionMock.shouldThrow = true
        }
        Telemetry.shared.session = sessionMock
    }

    func testTelemetryStart() {
        Telemetry.shared.sampleRate = 0.0
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        XCTAssertFalse(Telemetry.shared.started)
        
        Telemetry.shared.sampleRate = 1.0
        Telemetry.shared.start()
        XCTAssertTrue(Telemetry.shared.started)
        XCTAssertTrue(errors.isEmpty)
    }

    func testRollingUpDuplicateMetrics() {
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        for _ in 1...3 {
            Telemetry.shared.increment(metric: Telemetry.INVOKE_METRIC) { $0["test"] = "test" }
            Telemetry.shared.error(metric: Telemetry.INVOKE_ERROR_METRIC, log: "log") { $0["test"] = "test2" }
        }
        XCTAssertEqual(Telemetry.shared.queue.count, 2)
    }

    func testIncrementWhenTelemetryIsDisabled() {
        Telemetry.shared.enable = false
        Telemetry.shared.start()
        Telemetry.shared.increment(metric: Telemetry.INVOKE_METRIC) { $0["test"] = "test" }
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testIncrementWithWrongMetric() {
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        Telemetry.shared.increment(metric: "wrong_metric") { $0["test"] = "test" }
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testIncrementWithNoTags() {
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        Telemetry.shared.increment(metric: Telemetry.INVOKE_METRIC) { $0.removeAll() }
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testErrorWhenTelemetryIsDisabled() {
        Telemetry.shared.enable = false
        Telemetry.shared.start()
        Telemetry.shared.error(metric: Telemetry.INVOKE_ERROR_METRIC, log: "error") { $0["test"] = "test" }
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testErrorWithNoTags() {
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        Telemetry.shared.error(metric: Telemetry.INVOKE_ERROR_METRIC, log: "error") { $0.removeAll() }
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testFlushWorksEvenWhenTelemetryIsNotStarted() {
        Telemetry.shared.increment(metric: Telemetry.INVOKE_METRIC) { $0["test"] = "test" }
        Telemetry.shared.flush()
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testFlushWhenTelemetryIsDisabled() {
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        Telemetry.shared.enable = false
        Telemetry.shared.increment(metric: Telemetry.INVOKE_METRIC) { $0["test"] = "test" }
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testFlushWithEmptyQueue() {
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        Telemetry.shared.flush()
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertTrue(errors.isEmpty)
    }

    func testHTTPException() {
        mockTelemetryHTTPClient(shouldThrow: true)
        Telemetry.shared.flushFirstError = true
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        Telemetry.shared.error(metric: Telemetry.INVOKE_METRIC, log: "log") { $0["error"] = "test" }
        XCTAssertEqual(Telemetry.shared.queue.count, 0)
        XCTAssertEqual(errors.count, 1)
    }

    func testIncrementAndErrorMethodsWhenQueueIsFull() {
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        for i in 1...Telemetry.shared.maxQueueSize + 1 {
            Telemetry.shared.increment(metric: Telemetry.INVOKE_METRIC) { $0["test"] = "test\(i)" }
            Telemetry.shared.error(metric: Telemetry.INVOKE_ERROR_METRIC, log: "error") { $0["test"] = "test\(i)" }
        }
        XCTAssertEqual(Telemetry.shared.queue.count, Telemetry.shared.maxQueueSize)
    }

    func testErrorMethodWithDifferentFlagSettings() {
        let longString = String(repeating: "a", count: 1000)
        Telemetry.shared.enable = true
        Telemetry.shared.start()
        Telemetry.shared.sendWriteKeyOnError = false
        Telemetry.shared.sendErrorLogData = false
        Telemetry.shared.error(metric: Telemetry.INVOKE_ERROR_METRIC, log: longString) { $0["writekey"] = longString }
        XCTAssertTrue(Telemetry.shared.queue.count < 1000)
    }
}

// Mock URLSession
class URLSessionMock: RestrictedHTTPSession {
    typealias DataTaskType = DataTask

    typealias UploadTaskType = UploadTask

    var shouldThrow = false
    
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        if shouldThrow {
            completionHandler(nil, nil, NSError(domain: "Test", code: 1, userInfo: nil))
        } else {
            completionHandler(nil, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }
        return URLSessionDataTaskMock()
    }
}

// Mock URLSessionDataTask
class URLSessionDataTaskMock: URLSessionDataTask, @unchecked Sendable {
    override func resume() {}
}

#endif
