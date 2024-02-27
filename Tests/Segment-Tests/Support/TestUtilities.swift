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

extension XCTestCase {
    func checkIfLeaked(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            if instance != nil {
                print("Instance \(String(describing: instance)) is not nil")
            }
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak!", file: file, line: line)
        }
    }
}

#if !os(Linux) && !os(Windows)

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
