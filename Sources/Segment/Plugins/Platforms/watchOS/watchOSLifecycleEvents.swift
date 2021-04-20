//
//  watchOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 3/29/21.
//

import Foundation

#if os(watchOS)

// Work in progress ... TBD

class watchOSLifecycleMonitor: PlatformPlugin {
    static var specificName: String = "Segment_watchOSLifecycleMonitor"
    
    var type: PluginType
    var name: String
    var analytics: Analytics
    
    required init(name: String, analytics: Analytics) {
        self.type = .utility
        self.name = name
        self.analytics = analytics
    }
    
    // ...
}

#endif
