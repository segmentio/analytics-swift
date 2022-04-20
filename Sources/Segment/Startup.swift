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
        add(plugin: SegmentLog())
        add(plugin: StartupQueue())
        
        // add segment destination plugin unless
        // asked not to via configuration.
        if configuration.values.autoAddSegmentDestination {
            let segmentDestination = SegmentDestination()
            segmentDestination.analytics = self
            add(plugin: segmentDestination)
        }
        
        // Setup platform specific plugins
        if let platformPlugins = platformPlugins() {
            for plugin in platformPlugins {
                add(plugin: plugin)
            }
        }
        
        // plugins will receive any settings we currently have as they are added.
        // ... but lets go check if we have new stuff ....
        // start checking periodically for settings changes from segment.com
        setupSettingsCheck()
    }
    
    internal func platformPlugins() -> [PlatformPlugin]? {
        var plugins = [PlatformPlugin]()
        
        // add context plugin as well as it's platform specific internally.
        // this must come first.
        plugins.append(Context())
        
        plugins += VendorSystem.current.requiredPlugins

        // setup lifecycle if desired
        if configuration.values.trackApplicationLifecycleEvents {
            #if os(iOS) || os(tvOS)
            plugins.append(iOSLifecycleEvents())
            #endif
            #if os(watchOS)
            plugins.append(watchOSLifecycleEvents())
            #endif
            #if os(macOS)
            plugins.append(macOSLifecycleEvents())
            #endif
            #if os(Linux)
            // placeholder - not sure what this is yet
            //plugins.append(LinuxLifecycleMonitor())
            #endif
        }
        
        if plugins.isEmpty {
            return nil
        } else {
            return plugins
        }
    }
}

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit
extension Analytics {
    internal func setupSettingsCheck() {
        // do the first one
        checkSettings()
        // set up return-from-background to do it again.
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main) { (notification) in
            guard let app = notification.object as? UIApplication else { return }
            if app.applicationState == .background {
                self.checkSettings()
            }
        }
    }
}
#elseif os(watchOS)
extension Analytics {
    internal func setupSettingsCheck() {
        // TBD: we don't know what to do here yet.
        checkSettings()
    }
}
#elseif os(macOS)
import Cocoa
extension Analytics {
    internal func setupSettingsCheck() {
        // do the first one
        checkSettings()
        // now set up a timer to do it every 24 hrs.
        // mac apps change focus a lot more than iOS apps, so this
        // seems more appropriate here.
        QueueTimer.schedule(interval: .days(1), queue: .main) {
            self.checkSettings()
        }
    }
}
#elseif os(Linux)
extension Analytics {
    internal func setupSettingsCheck() {
        checkSettings()
    }
}
#endif
