//
//  macOSLifecycleEvents.swift
//  Segment
//
//  Created by Cody on 4/20/22.
//

import Foundation

#if os(macOS)

import Cocoa

class macOSLifecycleEvents: PlatformPlugin, macOSLifecycle {
    static var versionKey = "SEGVersionKey"
    static var buildKey = "SEGBuildKeyV2"
    
    let type = PluginType.before
    weak var analytics: Analytics?
    
    /// Since application:didFinishLaunchingWithOptions is not automatically called with Scenes / SwiftUI,
    /// this gets around by using a flag in user defaults to check for big events like application updating,
    /// being installed or even opening.
    @Atomic
    private var didFinishLaunching = false
    
    func application(didFinishLaunchingWithOptions launchOptions: [String : Any]?) {
        // Make sure we aren't double calling application:didFinishLaunchingWithOptions
        // by resetting the check at the start
        didFinishLaunching = true
        
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }

        let previousVersion = UserDefaults.standard.string(forKey: Self.versionKey)
        let previousBuild = UserDefaults.standard.string(forKey: Self.buildKey)
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        
        if previousBuild == nil {
            analytics?.track(name: "Application Installed", properties: [
                "version": currentVersion ?? "",
                "build": currentBuild ?? ""
            ])
        } else if currentBuild != previousBuild {
            analytics?.track(name: "Application Updated", properties: [
                "previous_version": previousVersion ?? "",
                "previous_build": previousBuild ?? "",
                "version": currentVersion ?? "",
                "build": currentBuild ?? ""
            ])
        }
        
        analytics?.track(name: "Application Opened", properties: [
            "from_background": false,
            "version": currentVersion ?? "",
            "build": currentBuild ?? ""
        ])
        
        UserDefaults.standard.setValue(currentVersion, forKey: Self.versionKey)
        UserDefaults.standard.setValue(currentBuild, forKey: Self.buildKey)
    }
    
    func applicationDidUnhide() {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        
        analytics?.track(name: "Application Unhidden", properties: [
            "from_background": true,
            "version": currentVersion ?? "",
            "build": currentBuild ?? ""
        ])
    }
    
    func applicationDidHide() {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        analytics?.track(name: "Application Hidden")
    }
    func applicationDidResignActive() {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        analytics?.track(name: "Application Backgrounded")
    }
    
    func applicationDidBecomeActive() {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        analytics?.track(name: "Application Foregrounded")
        
        // Lets check if we skipped application:didFinishLaunchingWithOptions,
        // if so, lets call it.
        if didFinishLaunching == false {
            // Call application did finish launching
            self.application(didFinishLaunchingWithOptions: nil)
        }
    }
    
    func applicationWillTerminate() {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        analytics?.track(name: "Application Terminated")
    }
}

#endif
