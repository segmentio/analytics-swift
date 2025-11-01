//
//  watchOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 3/29/21.
//

#if os(watchOS)

import Foundation
import WatchKit

class watchOSLifecycleEvents: PlatformPlugin, watchOSLifecycle {
    let type = PluginType.before
    weak var analytics: Analytics?
    
    @Atomic
    private var didCheckInstallOrUpdate = false
    
    func configure(analytics: Analytics) {
        self.analytics = analytics
        
        // Check install/update immediately to catch first launch
        if !didCheckInstallOrUpdate {
            analytics.checkAndTrackInstallOrUpdate()
            _didCheckInstallOrUpdate.set(true)
        }
    }
    
    func applicationDidFinishLaunching(watchExtension: WKExtension) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents == TrackedLifecycleEvent.none {
            return
        }
        
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            analytics?.trackApplicationOpened(fromBackground: false)
        }
    }
    
    func applicationWillEnterForeground(watchExtension: WKExtension) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            analytics?.trackApplicationOpened(fromBackground: true)
        }
    }
    
    func applicationDidEnterBackground(watchExtension: WKExtension) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationBackgrounded) == true {
            analytics?.trackApplicationBackgrounded()
        }
    }
}

#endif
