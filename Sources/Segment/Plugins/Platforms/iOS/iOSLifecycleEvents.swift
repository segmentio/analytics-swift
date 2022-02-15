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
    var analytics: Analytics?
    
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
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
            "build": currentBuild ?? "",
            "referring_application": launchOptions?[UIApplication.LaunchOptionsKey.sourceApplication] ?? "",
            "url": launchOptions?[UIApplication.LaunchOptionsKey.url] ?? ""
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
        
        analytics?.track(name: "Application Foregrounded", properties: [
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
}

#endif
