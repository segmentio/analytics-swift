//
//  macOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation

// TODO: fill this out later.

#if os(macOS)
class macOSLifecycleEvents: PlatformExtension {
    static var specificName = "Segment_macOSLifecycleEvents"
    let type: ExtensionType
    let name: String
    let analytics: Analytics
    
    required init(name: String, analytics: Analytics) {
        self.type = .utility
        self.analytics = analytics
        self.name = name
    }
}
#endif
