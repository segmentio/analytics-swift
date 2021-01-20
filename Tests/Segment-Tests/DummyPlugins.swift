//
//  DummyPlugins.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 1/6/21.
//

import Foundation
import Segment

// MARK: - Helper Classes
struct MyTraits: Codable {
    let email: String?
}

class GooberPlugin: EventPlugin {
    let type: PluginType
    let name: String
    let analytics: Analytics
    
    required init(name: String, analytics: Analytics) {
        self.name = name
        self.analytics = analytics
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
    let analytics: Analytics
    
    var completion: (() -> Void)?
    
    required init(name: String, analytics: Analytics) {
        self.name = name
        self.analytics = analytics
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
    func reloadWithSettings(_ settings: Settings) {
        //
    }
    
    var plugins: Plugins
    
    let type: PluginType
    let name: String
    let analytics: Analytics
    
    required init(name: String, analytics: Analytics) {
        self.name = name
        self.analytics = analytics
        self.type = .destination
        self.plugins = Plugins()
    }
}
