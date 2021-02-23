//
//  Startup.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation
import Sovran

extension Analytics: Subscriber {
        
    internal func platformStartup() {
        // add segment destination plugin unless
        // asked not to via configuration.
        if configuration.values.autoAddSegmentDestination {
            let segmentDestination = SegmentDestination(name: "Segment.io", analytics: self)
            segmentDestination.analytics = self
            add(plugin: segmentDestination)
        }
        
        // Setup platform specific plugins
        if let platformPlugins = platformPlugins() {
            for pluginType in platformPlugins {
                let prebuilt = pluginType.init(name: pluginType.specificName, analytics: self)
                add(plugin: prebuilt)
            }
        }
        
        // prepare our subscription for settings updates from segment.com
        store.subscribe(self, initialState: true) { (state: System) in
            print(state)
            if let settings = state.settings {
                self.update(settings: settings)
            }
        }
        
        // plugins will receive any settings we currently have as they are added.
        // ... but lets go check if we have new stuff ....
        // start checking periodically for settings changes from segment.com
        setupSettingsCheck()
    }
    
    internal func update(settings: Settings) {
        apply { (plugin) in
            // tell all top level plugins to update.
            update(plugin: plugin, settings: settings)
        }
    }
    
    internal func update(plugin: Plugin, settings: Settings) {
        plugin.update(settings: settings)
        // if it's a destination, tell it's plugins to update as well.
        if let dest = plugin as? DestinationPlugin {
            dest.apply { (subPlugin) in
                subPlugin.update(settings: settings)
            }
        }
    }
    
    internal func platformPlugins() -> [PlatformPlugin.Type]? {
        var plugins = [PlatformPlugin.Type]()
        
        // setup lifecycle if desired
        if configuration.values.trackApplicationLifecycleEvents {
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
