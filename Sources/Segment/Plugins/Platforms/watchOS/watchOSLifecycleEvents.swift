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
    static var versionKey = "SEGVersionKey"
    static var buildKey = "SEGBuildKeyV2"
    
    let type = PluginType.before
    weak var analytics: Analytics?
    
    func applicationDidFinishLaunching(watchExtension: WKExtension) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents == TrackedLifecycleEvent.none {
            return
        }
        
        let previousVersion = UserDefaults.standard.string(forKey: Self.versionKey)
        let previousBuild = UserDefaults.standard.string(forKey: Self.buildKey)
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        
        if previousBuild == nil {
            if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationInstalled) == true {
                analytics?.track(name: "Application Installed", properties: [
                    "version": currentVersion ?? "",
                    "build": currentBuild ?? ""
                ])
            }
        } else if currentBuild != previousBuild {
            if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationUpdated) == true {
                analytics?.track(name: "Application Updated", properties: [
                    "previous_version": previousVersion ?? "",
                    "previous_build": previousBuild ?? "",
                    "version": currentVersion ?? "",
                    "build": currentBuild ?? ""
                ])
            }
        }
        
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            analytics?.track(name: "Application Opened", properties: [
                "from_background": false,
                "version": currentVersion ?? "",
                "build": currentBuild ?? ""
            ])
        }
        
        UserDefaults.standard.setValue(currentVersion, forKey: Self.versionKey)
        UserDefaults.standard.setValue(currentBuild, forKey: Self.buildKey)
    }
    
    func applicationWillEnterForeground(watchExtension: WKExtension) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            
            analytics?.track(name: "Application Opened", properties: [
                "from_background": true,
                "version": currentVersion ?? "",
                "build": currentBuild ?? ""
            ])
        }
    }
    
    func applicationDidEnterBackground(watchExtension: WKExtension) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationBackgrounded) == true {
            analytics?.track(name: "Application Backgrounded")
        }
    }
}

#endif
