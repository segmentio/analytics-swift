//
//  LinuxLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation

#if os(Linux)
class LinuxLifecycleEvents: PlatformPlugin {
    static var specificName = "Segment_LinuxLifecycleEvents"
    let type: PluginType
    let name: String
    
    weak var analytics: Analytics? = nil
    
    required init(name: String) {
        self.type = .utility
        self.name = name
    }
    
    convenience init(name: String, analytics: Analytics) {
        self.init(name: name)
        self.analytics = analytics
    }

}
#endif
