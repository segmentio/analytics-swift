//
//  TestPlugins.swift
//  SegmentExample
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation
import Segment

class GooberPlugin: EventPlugin {
    var analytics: Analytics?
    let type: PluginType
    let name: String
    
    required init(name: String) {
        self.name = name
        self.type = .enrichment
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        var newEvent = IdentifyEvent(existing: event)
        newEvent.userId = "goober"
        return newEvent
        //return nil
    }
}

class ZiggyPlugin: EventPlugin {
    var analytics: Analytics?
    let type: PluginType
    let name: String
    
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
    var analytics: Analytics?
    
    var timeline: Timeline
    let type: PluginType
    let name: String
    
    required init(name: String) {
        self.name = name
        self.type = .destination
        self.timeline = Timeline()
    }
    
    func reloadWithSettings(_ settings: Settings) {
        // TODO: Update the proper types
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
}

class AfterPlugin: Plugin {
    var analytics: Analytics?
    
    var timeline: Timeline
    let type: PluginType
    let name: String
    
    required init(name: String) {
        self.name = name
        self.type = .after
        self.timeline = Timeline()
    }
    
    public func execute<T: RawEvent>(event: T?, settings: Settings?) -> T? {
        print(event.prettyPrint())
        return event
    }
}
