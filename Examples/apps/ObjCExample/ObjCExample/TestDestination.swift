//
//  TestDestination.swift
//  ObjCExample
//
//  Created by Brandon Sneed on 4/14/23.
//

import Foundation
import Segment

@objc(CIOTestDestination)
public class ObjCTestDestination: NSObject, ObjCPlugin, ObjCPluginShim {
    public func instance() -> EventPlugin { return TestDestination() }
}

public class TestDestination: DestinationPlugin {
    public let key = "Booya"
    public let timeline = Timeline()
    public let type = PluginType.destination
    public var analytics: Analytics? = nil
    
    public func configure(analytics: Analytics) {
        analytics.manuallyEnableDestination(plugin: self)
        self.analytics = analytics
    }
    
    public func update(settings: Settings, type: UpdateType) {
       // analytics?.manuallyEnableDestination(plugin: self)
    }
    
    public func track(event: TrackEvent) -> TrackEvent? {
        print("Event Received: \n")
        print(event.prettyPrint())
        return event
    }
}
