//
//  macOSLifecycleEvents.swift
//  Segment
//
//  Created by Cody on 4/20/22.
//

#if os(macOS)

import Foundation
import Cocoa

class macOSLifecycleEvents: PlatformPlugin, macOSLifecycle {
    let type = PluginType.before
    weak var analytics: Analytics?
    
    @Atomic
    private var didFinishLaunching = false
    
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
    
    func application(didFinishLaunchingWithOptions launchOptions: [String : Any]?) {
        _didFinishLaunching.set(true)

        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            analytics?.trackApplicationOpened(fromBackground: false)
        }
    }
    
    func applicationDidUnhide() {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationUnhidden) == true {
            analytics?.track(name: "Application Unhidden", properties: [
                "from_background": true,
                "version": Analytics.appCurrentVersion,
                "build": Analytics.appCurrentBuild
            ])
        }
    }
    
    func applicationDidHide() {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationHidden) == true {
            analytics?.track(name: "Application Hidden")
        }
    }
    
    func applicationDidResignActive() {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationBackgrounded) == true {
            analytics?.trackApplicationBackgrounded()
        }
    }
    
    func applicationDidBecomeActive() {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationForegrounded) == true {
            analytics?.trackApplicationForegrounded()
        }
        
        // Lets check if we skipped application:didFinishLaunchingWithOptions,
        // if so, lets call it.
        if didFinishLaunching == false {
            // Call application did finish launching
            self.application(didFinishLaunchingWithOptions: nil)
        }
    }
    
    func applicationWillTerminate() {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationTerminated) == true {
            analytics?.track(name: "Application Terminated")
        }
    }
}

#endif
