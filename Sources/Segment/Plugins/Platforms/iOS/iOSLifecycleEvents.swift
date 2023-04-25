//
//  iOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 4/7/21.
//

import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import UIKit

class iOSLifecycleEvents: PlatformPlugin, iOSLifecycle {
    static var versionKey = "SEGVersionKey"
    static var buildKey = "SEGBuildKeyV2"
    
    let type = PluginType.before
    weak var analytics: Analytics?
    
    /// Since application:didFinishLaunchingWithOptions is not automatically called with Scenes / SwiftUI,
    /// this gets around by using a flag in user defaults to check for big events like application updating,
    /// being installed or even opening.
    @Atomic
    private var didFinishLaunching = false
    
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        
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
        
        let sourceApp: String? = launchOptions?[UIApplication.LaunchOptionsKey.sourceApplication] as? String ?? ""
        let url: String? = launchOptions?[UIApplication.LaunchOptionsKey.url] as? String ?? ""
        
        analytics?.track(name: "Application Opened", properties: [
            "from_background": false,
            "version": currentVersion ?? "",
            "build": currentBuild ?? "",
            "referring_application": sourceApp ?? "",
            "url": url ?? ""
        ])
        
        UserDefaults.standard.setValue(currentVersion, forKey: Self.versionKey)
        UserDefaults.standard.setValue(currentBuild, forKey: Self.buildKey)
    }
    
    func applicationWillEnterForeground(application: UIApplication?) {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        
        analytics?.track(name: "Application Opened", properties: [
            "from_background": true,
            "version": currentVersion ?? "",
            "build": currentBuild ?? ""
        ])
    }
    
    func applicationDidEnterBackground(application: UIApplication?) {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        analytics?.track(name: "Application Backgrounded")
    }
    
    func applicationDidBecomeActive(application: UIApplication?) {
        if analytics?.configuration.values.trackApplicationLifecycleEvents == false {
            return
        }
        
        analytics?.track(name: "Application Foregrounded")
        
        // Lets check if we skipped application:didFinishLaunchingWithOptions,
        // if so, lets call it.
        if didFinishLaunching == false {
            // Call application did finish launching
            self.application(nil, didFinishLaunchingWithOptions: nil)
        }
    }
}

#endif
