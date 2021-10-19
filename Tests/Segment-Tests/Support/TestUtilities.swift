//
//  TestUtilities.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 1/6/21.
//

import Foundation
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
    var analytics: Analytics?
    
    init() {
        self.type = .enrichment
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        let beginningTime = Date()
        var newEvent = IdentifyEvent(existing: event)
        newEvent.userId = "goober"
        sleep(3)
        let endingTime = Date()
        let finalTime = endingTime.timeIntervalSince(beginningTime)
        
        Analytics.segmentMetric(.gauge, name: "Gauge Test", value: finalTime, tags: ["timing", "function_length"])
        
        return newEvent
        //return nil
    }
}

class ZiggyPlugin: EventPlugin {
    let type: PluginType
    var analytics: Analytics?
    
    var completion: (() -> Void)?
    
    required init() {
        self.type = .enrichment
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

class MyDestination: DestinationPlugin {
    var timeline: Timeline
    let type: PluginType
    let key: String
    var analytics: Analytics?
    let trackCompletion: (() -> Bool)?
    
    init(trackCompletion: (() -> Bool)? = nil) {
        self.key = "MyDestination"
        self.type = .destination
        self.timeline = Timeline()
        self.trackCompletion = trackCompletion
    }
    
    func update(settings: Settings, type: UpdateType) {
        //
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
    var analytics: Analytics?
    
    var lastEvent: RawEvent? = nil
    
    init() {
        self.type = .after
    }
    
    func execute<T>(event: T?) -> T? where T : RawEvent {
        lastEvent = event
        if let t = lastEvent as? TrackEvent {
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
