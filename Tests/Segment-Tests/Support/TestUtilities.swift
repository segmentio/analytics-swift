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
    let name: String
    var analytics: Analytics?
    
    required init(name: String) {
        self.name = name
        self.type = .enrichment
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        let beginningTime = Date()
        var newEvent = IdentifyEvent(existing: event)
        newEvent.userId = "goober"
        sleep(3)
        let endingTime = Date()
        let finalTime = endingTime.timeIntervalSince(beginningTime)
        
        newEvent.addMetric(.gauge, name: "Gauge Test", value: finalTime, tags: ["timing", "function_length"], timestamp: Date())
        
        return newEvent
        //return nil
    }
}

class ZiggyPlugin: EventPlugin {
    let type: PluginType
    let name: String
    var analytics: Analytics?
    
    var completion: (() -> Void)?
    
    required init(name: String) {
        self.name = name
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
    let name: String
    var analytics: Analytics?
    
    required init(name: String) {
        self.name = name
        self.type = .destination
        self.timeline = Timeline()
    }
    
    func update(settings: Settings) {
        //
    }
    
}

class OutputReaderPlugin: Plugin {
    let type: PluginType
    let name: String
    var analytics: Analytics?
    
    var lastEvent: RawEvent? = nil
    
    required init(name: String) {
        self.type = .after
        self.name = name
    }
    
    func execute<T>(event: T?) -> T? where T : RawEvent {
        lastEvent = event
        return event
    }
}

func waitUntilStarted(analytics: Analytics?) {
    guard let analytics = analytics else { return }
    var started = false
    while started == false {
        if let system: System = analytics.store.currentState() {
            if system.started {
                started = true
            }
        }
        RunLoop.main.run(until: Date.distantPast)
    }
}
