#if !os(Linux) && !os(Windows)

import XCTest
@testable import Segment

// answers every request with a 200 and records the size of each upload body.
private final class RecordingProtocol: URLProtocol {
    static let lock = NSLock()
    static var bodySizes: [Int] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var size = request.httpBody?.count ?? 0
        if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            size = 0
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                size += read
            }
            stream.close()
        }
        Self.lock.lock(); Self.bodySizes.append(size); Self.lock.unlock()

        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private class SettingsTask: UploadTask, DataTask {
    var state: URLSessionTask.State = .completed
    func resume() {}
}

// real URLSession upload tasks; the first upload's completion is held until the test releases it.
private class GatedSession: HTTPSession {
    private let session: URLSession
    let firstCompletionEntered = DispatchSemaphore(value: 0)
    let releaseFirstCompletion = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private(set) var uploadedFiles: [URL] = []

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingProtocol.self]
        session = URLSession(configuration: configuration)
    }

    func uploadTask(with request: URLRequest, fromFile file: URL,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        lock.lock()
        uploadedFiles.append(file)
        let isFirst = uploadedFiles.count == 1
        lock.unlock()
        return session.uploadTask(with: request, fromFile: file) { [self] data, response, error in
            if isFirst {
                firstCompletionEntered.signal()
                releaseFirstCompletion.wait()
            }
            completionHandler(data, response, error)
        }
    }

    func uploadTask(with request: URLRequest, from bodyData: Data?,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        return session.uploadTask(with: request, from: bodyData ?? Data(), completionHandler: completionHandler)
    }

    func dataTask(with request: URLRequest,
                  completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> SettingsTask {
        DispatchQueue.global().async {
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            let settings = """
            {"integrations":{"Segment.io":{"apiKey":"test"}},"plan":{"track":{"__default":{"enabled":true}}}}
            """.data(using: .utf8)
            completionHandler(settings, response, nil)
        }
        return SettingsTask()
    }

    // the SDK invalidates its session when settings rebuild the HTTP client; keep ours usable.
    func finishTasksAndInvalidate() {}

    deinit {
        session.finishTasksAndInvalidate()
    }
}

// holds upload completions until the test fires them.
private class HeldCompletionSession: HTTPSession {
    private(set) var held: [@Sendable (Data?, URLResponse?, (any Error)?) -> Void] = []

    func uploadTask(with request: URLRequest, fromFile file: URL,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> SettingsTask {
        held.append(completionHandler)
        return SettingsTask()
    }

    func uploadTask(with request: URLRequest, from bodyData: Data?,
                    completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> SettingsTask {
        held.append(completionHandler)
        return SettingsTask()
    }

    func dataTask(with request: URLRequest,
                  completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> SettingsTask {
        return SettingsTask()
    }

    func finishTasksAndInvalidate() {}
}

class UploadOwnership_Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        Telemetry.shared.enable = false
        RecordingProtocol.lock.lock(); RecordingProtocol.bodySizes = []; RecordingProtocol.lock.unlock()
    }

    // URLSession marks a task .completed before running its completion handler, so a flush
    // in that window must not treat the batch as free and upload it a second time.
    func testFlushDoesNotReuploadBatchWhoseCompletionIsStillRunning() {
        let session = GatedSession()
        let flushQueue = DispatchQueue(label: "com.segment.test.uploadOwnership")
        let config = Configuration(writeKey: uniqueWriteKey())
            .flushInterval(9999)
            .flushAt(9999)
            .operatingMode(.asynchronous)
            .flushQueue(flushQueue)
            .storageMode(.disk)
            .trackApplicationLifecycleEvents(false)
            .httpSession(session)

        let analytics = Analytics(configuration: config)
        waitUntilStarted(analytics: analytics)
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        analytics.track(name: "only event")
        analytics.flush()

        // upload A got its response; its task is .completed and the SDK hasn't processed it yet.
        XCTAssertEqual(session.firstCompletionEntered.wait(timeout: .now() + 10), .success)

        analytics.flush()
        flushQueue.sync {}

        session.releaseFirstCompletion.signal()
        // let A's completion and any second upload finish.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        flushQueue.sync {}

        XCTAssertEqual(session.uploadedFiles.count, 1, "uploaded \(session.uploadedFiles.map { $0.lastPathComponent }); body sizes \(RecordingProtocol.bodySizes)")
    }

    // settings replace the HTTPClient, possibly mid-upload; the upload's completion must still run,
    // or its batch would stay pending and block every later flush.
    func testUploadCompletionRunsAfterHTTPClientIsReleased() {
        let session = HeldCompletionSession()
        let config = Configuration(writeKey: uniqueWriteKey())
            .flushInterval(9999)
            .flushAt(9999)
            .trackApplicationLifecycleEvents(false)
            .httpSession(session)
        let analytics = Analytics(configuration: config)

        var client: HTTPClient? = HTTPClient(analytics: analytics)
        let completed = expectation(description: "upload completion ran")
        client?.startBatchUpload(writeKey: "test", data: Data("{}".utf8), batchId: "batch") { result in
            if case .failure(HTTPClientErrors.badSession) = result {
                completed.fulfill()
            }
        }
        client = nil

        let url = URL(string: "https://api.segment.io/v1/b")!
        session.held.last?(nil, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        wait(for: [completed], timeout: 2.0)
    }
}

#endif
