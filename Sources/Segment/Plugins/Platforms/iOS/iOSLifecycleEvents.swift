//
//  iOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 4/7/21.
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)

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
        _didFinishLaunching.set(true)

        let previousVersion: String? = UserDefaults.standard.string(forKey: Self.versionKey)
        let previousBuild: String? = UserDefaults.standard.string(forKey: Self.buildKey)

        let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        if previousBuild == nil {
            if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationInstalled) == true {
                analytics?.track(name: "Application Installed", properties: [
                    "version": currentVersion,
                    "build": currentBuild
                ])
            }
        } else if let previousBuild, currentBuild != previousBuild {
            if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationUpdated) == true {
                analytics?.track(name: "Application Updated", properties: [
                    "previous_version": previousVersion ?? "",
                    "previous_build": previousBuild,
                    "version": currentVersion,
                    "build": currentBuild
                ])
            }
        }

        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            let sourceApp: String = launchOptions?[UIApplication.LaunchOptionsKey.sourceApplication] as? String ?? ""
            let url = urlFrom(launchOptions)

            analytics?.track(name: "Application Opened", properties: [
                "from_background": false,
                "version": currentVersion,
                "build": currentBuild,
                "referring_application": sourceApp,
                "url": url
            ])
        }
        
        UserDefaults.standard.setValue(currentVersion, forKey: Self.versionKey)
        UserDefaults.standard.setValue(currentBuild, forKey: Self.buildKey)
    }
    
    func applicationWillEnterForeground(application: UIApplication?) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

            if didFinishLaunching == false {
                analytics?.track(name: "Application Opened", properties: [
                    "from_background": true,
                    "version": currentVersion ?? "",
                    "build": currentBuild ?? ""
                ])
            }
        }
    }
    
    func applicationDidEnterBackground(application: UIApplication?) {
        _didFinishLaunching.set(false)
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationBackgrounded) == true {
            analytics?.track(name: "Application Backgrounded")
        }
    }
    
    func applicationDidBecomeActive(application: UIApplication?) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationForegrounded) == true {
            analytics?.track(name: "Application Foregrounded")
        }
    }
    
    private func urlFrom(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> String {
        if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? String {
            return url
        }
        if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? NSURL, let rawUrl =  url.absoluteString  {
            return rawUrl
        }
        return ""
    }
}

#endif
