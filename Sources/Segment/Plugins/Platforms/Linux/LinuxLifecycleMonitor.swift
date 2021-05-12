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
    
    var analytics: Analytics?
    
    required init(name: String) {
        self.type = .utility
        self.name = name
    }

}
#endif
