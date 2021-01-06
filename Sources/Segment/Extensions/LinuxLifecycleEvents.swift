//
//  LinuxLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation

#if os(Linux)
class LinuxLifecycleEvents: PlatformExtension {
    static var specificName = "Segment_LinuxLifecycleEvents"
    let type: ExtensionType
    let name: String
    
    weak var analytics: Analytics? = nil
    
    required init(name: String) {
        self.type = .before
        self.name = name
    }
    
    convenience init(name: String, analytics: Analytics) {
        self.init(name: name)
        self.analytics = analytics
    }

}
#endif
