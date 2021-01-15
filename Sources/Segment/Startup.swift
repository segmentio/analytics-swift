//
//  Startup.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

extension Analytics {
        
    internal func platformStartup() {
        
        // add segment destination plugin
        // ...
        let segmentDestination = SegmentDestination(name: "SegmentDestination", analytics: self)
        segmentDestination.analytics = self
        plugins.add(segmentDestination)
        
        // Setup platform specific plugins
        if let platformPlugins = platformPlugins() {
            for pluginType in platformPlugins {
                let prebuilt = pluginType.init(name: pluginType.specificName, analytics: self)
                plugins.add(prebuilt)
            }
        }
        
        // other setup/config stuff.
        // ...
        
        setupSettingsCheck()
    }
    
    internal func platformPlugins() -> [PlatformPlugin.Type]? {
        var plugins = [PlatformPlugin.Type]()
        
        // setup lifecycle if desired
        if configuration.trackApplicationLifecycleEvents {
            #if os(iOS) || os(watchOS) || os(tvOS)
            plugins += [iOSLifecycleEvents.self, iOSAppBackground.self]
            #endif
            #if os(macOS)
            plugins.append(macOSLifecycleEvents.self)
            #endif
            #if os(Linux)
            plugins.append(LinuxLifecycleEvents.self)
            #endif
        }
        
        if plugins.isEmpty {
            return nil
        } else {
            return plugins
        }
    }
}

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
extension Analytics {
    internal func setupSettingsCheck() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main) { (notification) in
            self.checkSettings()
        }
    }
}
#elseif os(macOS)
import Cocoa
extension Analytics {
    internal func setupSettingsCheck() {
        NotificationCenter.default.addObserver(forName: NSApplication.willBecomeActiveNotification, object: nil, queue: OperationQueue.main) { (notification) in
            self.checkSettings()
        }
    }
}
#elseif os(Linux)
extension Analytics {
    internal func setupSettingsCheck() {
        // TBD: we don't know what to do here.
    }
}
#endif
