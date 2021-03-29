//
//  watchOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 3/29/21.
//

import Foundation

#if os(watchOS)

// Work in progress ... TBD

class watchOSLifecycleEvents: PlatformPlugin {
    static var specificName: String = "Segment_watchOSLifecycleEvents"
    
    var type: PluginType
    var name: String
    var analytics: Analytics
    
    required init(name: String, analytics: Analytics) {
        self.type = .utility
        self.name = watchOSLifecycleEvents.specificName
        self.analytics = analytics
    }
    
    // ...
}

#endif
