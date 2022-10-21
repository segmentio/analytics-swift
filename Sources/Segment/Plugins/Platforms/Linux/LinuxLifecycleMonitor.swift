//
//  LinuxLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation

#if os(Linux)
class LinuxLifecycleMonitor: PlatformPlugin {
    let type = PluginType.utility
    weak var analytics: Analytics?
}
#endif
