//
//  LinuxLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation

#if os(Linux)
class LinuxLifecycleMonitor: PlatformPlugin {
    static var specificName = "Segment_LinuxLifecycleMonitor"
    let type: PluginType
    let name: String
    
    weak var analytics: Analytics? = nil
    
    required init(name: String, analytics: Analytics) {
        self.type = .utility
        self.name = name
        self.analytics = analytics
    }

}
#endif
