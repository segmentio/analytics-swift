//
//  TestUtilities.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 1/6/21.
//

import Foundation
import XCTest
@testable import Segment

extension UUID{
    public func asUInt8Array() -> [UInt8]{
        let (u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15,u16) = self.uuid
        return [u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15,u16]
    }
    public func asData() -> Data{
        return Data(self.asUInt8Array())
    }
}

// MARK: - Helper Classes
struct MyTraits: Codable {
    let email: String?
}

class GooberPlugin: EventPlugin {
    let type: PluginType
    weak var analytics: Analytics?
    
    init() {
        self.type = .enrichment
    }

    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        var newEvent = IdentifyEvent(existing: event)
        newEvent.userId = "goober"
        return newEvent
    }
}

class ZiggyPlugin: EventPlugin {
    let type: PluginType
    weak var analytics: Analytics?
    var receivedInitialUpdate: Int = 0

    var completion: (() -> Void)?

    required init() {
        self.type = .enrichment
    }

    func update(settings: Settings, type: UpdateType) {
        if type == .initial { receivedInitialUpdate += 1 }
    }

    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        var newEvent = IdentifyEvent(existing: event)
        newEvent.userId = "ziggy"
        return newEvent
        //return nil
    }

    func shutdown() {
        completion?()
    }
}

#if !os(Linux) && !os(Windows)

@objc(SEGMyDestination)
public class ObjCMyDestination: NSObject, ObjCPlugin, ObjCPluginShim {
    public func instance() -> EventPlugin { return MyDestination() }
}

#endif

class MyDestination: DestinationPlugin {
    var timeline: Timeline
    let type: PluginType
    let key: String
    weak var analytics: Analytics?
    let trackCompletion: (() -> Bool)?

    let disabled: Bool
    var receivedInitialUpdate: Int = 0

    init(disabled: Bool = false, trackCompletion: (() -> Bool)? = nil) {
        self.key = "MyDestination"
        self.type = .destination
        self.timeline = Timeline()
        self.trackCompletion = trackCompletion
        self.disabled = disabled
    }

    func update(settings: Settings, type: UpdateType) {
        if type == .initial { receivedInitialUpdate += 1 }
        if disabled == false {
            // add ourselves to the settings
            analytics?.manuallyEnableDestination(plugin: self)
        }
    }

    func track(event: TrackEvent) -> TrackEvent? {
        var returnEvent: TrackEvent? = event
        if let completion = trackCompletion {
            if !completion() {
                returnEvent = nil
            }
        }
        return returnEvent
    }
}

class OutputReaderPlugin: Plugin {
    let type: PluginType
    weak var analytics: Analytics?
    
    var events = [RawEvent]()
    var lastEvent: RawEvent? = nil

    init() {
        self.type = .after
    }

    func execute<T>(event: T?) -> T? where T : RawEvent {
        lastEvent = event
        if let t = lastEvent as? TrackEvent {
            events.append(t)
            print("EVENT: \(t.event)")
        }
        return event
    }
}

func waitUntilStarted(analytics: Analytics?) {
    guard let analytics = analytics else { return }
    // wait until the startup queue has emptied it's events.
    if let startupQueue = analytics.find(pluginType: StartupQueue.self) {
        while startupQueue.running != true {
            RunLoop.main.run(until: Date.distantPast)
        }
    }
}

struct TimedOutError: Error, Equatable {}

public func waitForTaskCompletion<R>(
    withTimeoutInSeconds timeout: UInt64,
    _ task: @escaping () async throws -> R
) async throws -> R {
    return try await withThrowingTaskGroup(of: R.self) { group in
        await withUnsafeContinuation { continuation in
            group.addTask {
                continuation.resume()
                return try await task()
            }
        }
        group.addTask {
            await Task.yield()
            try await Task.sleep(nanoseconds: timeout * 1_000_000_000)
            throw TimedOutError()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

extension XCTestCase {
    func checkIfLeaked(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            if instance != nil {
                print("Instance \(String(describing: instance)) is not nil")
            }
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak!", file: file, line: line)
        }
    }
    
    func waitUntilFinished(analytics: Analytics?, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak analytics] in
            let instance = try await waitForTaskCompletion(withTimeoutInSeconds: 3) {
                while analytics != nil {
                    DispatchQueue.main.sync {
                        RunLoop.current.run(until: .distantPast)
                    }
                }
                return analytics
            }
            XCTAssertNil(instance, "Analytics should have been deallocated. It's likely a memory leak!", file: file, line: line)
        }
    }
}

#if !os(Linux) && !os(Windows)

class RestrictedHTTPSession: HTTPSession {
    let sesh: URLSession
    static var fileUploads: Int = 0
    static var dataUploads: Int = 0
    static var dataTasks: Int = 0
    static var invalidated: Int = 0
    
    init(blocking: Bool = true, failing: Bool = false) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForResource = 30
        configuration.timeoutIntervalForRequest = 60
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json; charset=utf-8",
                                               "Authorization": "Basic test",
                                               "User-Agent": "analytics-ios/\(Analytics.version())"]
        
        var protos = [URLProtocol.Type]()
        if blocking { protos.append(BlockNetworkCalls.self) }
        if failing { protos.append(FailedNetworkCalls.self) }
        configuration.protocolClasses = protos
        
        sesh = URLSession(configuration: configuration)
    }
    
    static func reset() {
        fileUploads = 0
        dataUploads = 0
        dataTasks = 0
        invalidated = 0
    }
    
    func uploadTask(with request: URLRequest, fromFile file: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        defer { Self.fileUploads += 1 }
        return sesh.uploadTask(with: request, fromFile: file, completionHandler: completionHandler)
    }
    
    func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionUploadTask {
        defer { Self.dataUploads += 1 }
        return sesh.uploadTask(with: request, from: bodyData, completionHandler: completionHandler)
    }
    
    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        defer { Self.dataTasks += 1 }
        return sesh.dataTask(with: request, completionHandler: completionHandler)
    }
    
    func finishTasksAndInvalidate() {
        defer { Self.invalidated += 1 }
        sesh.finishTasksAndInvalidate()
    }
}



class BlockNetworkCalls: URLProtocol {
    var initialURL: URL? = nil
    override class func canInit(with request: URLRequest) -> Bool {

        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override var cachedResponse: CachedURLResponse? { return nil }

    override func startLoading() {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: URL(string: "http://api.segment.com")!, statusCode: 200, httpVersion: nil, headerFields: ["blocked": "true"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {

    }
}

class FailedNetworkCalls: URLProtocol {
    var initialURL: URL? = nil
    override class func canInit(with request: URLRequest) -> Bool {
        
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override var cachedResponse: CachedURLResponse? { return nil }
    
    override func startLoading() {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: URL(string: "http://api.segment.com")!, statusCode: 400, httpVersion: nil, headerFields: ["blocked": "true"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        
    }
}

#endif
