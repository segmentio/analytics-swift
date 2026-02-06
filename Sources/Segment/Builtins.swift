//
//  Builtins.swift
//  Segment
//
//  Created by Brandon Sneed on 10/31/25.
//

import Foundation

extension Analytics {
    internal static let versionKey = "SEGVersionKey"
    internal static let buildKey = "SEGBuildKeyV2"
    
    internal static var appCurrentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    internal static var appCurrentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    
    public func checkAndTrackInstallOrUpdate() {
        let previousVersion = UserDefaults.standard.string(forKey: Self.versionKey)
        let previousBuild = UserDefaults.standard.string(forKey: Self.buildKey)
        
        if previousBuild == nil {
            // Fresh install
            if configuration.values.trackedApplicationLifecycleEvents.contains(.applicationInstalled) {
                trackApplicationInstalled(version: Self.appCurrentVersion, build: Self.appCurrentBuild)
            }
        } else if let previousBuild, Self.appCurrentBuild != previousBuild {
            // App was updated
            if configuration.values.trackedApplicationLifecycleEvents.contains(.applicationUpdated) {
                trackApplicationUpdated(
                    previousVersion: previousVersion ?? "",
                    previousBuild: previousBuild,
                    version: Self.appCurrentVersion,
                    build: Self.appCurrentBuild
                )
            }
        }
        
        // Always update UserDefaults
        UserDefaults.standard.setValue(Self.appCurrentVersion, forKey: Self.versionKey)
        UserDefaults.standard.setValue(Self.appCurrentBuild, forKey: Self.buildKey)
    }
    
    /// Tracks an Application Installed event.
    /// - Parameters:
    ///   - version: The app version (e.g., "1.0.0")
    ///   - build: The app build number (e.g., "42")
    public func trackApplicationInstalled(version: String, build: String) {
        track(name: "Application Installed", properties: [
            "version": version,
            "build": build
        ])
    }
    
    /// Tracks an Application Updated event.
    /// - Parameters:
    ///   - previousVersion: The previous app version
    ///   - previousBuild: The previous build number
    ///   - version: The current app version
    ///   - build: The current build number
    public func trackApplicationUpdated(previousVersion: String, previousBuild: String, version: String, build: String) {
        track(name: "Application Updated", properties: [
            "previous_version": previousVersion,
            "previous_build": previousBuild,
            "version": version,
            "build": build
        ])
    }
    
    /// Tracks an Application Opened event.
    /// - Parameters:
    ///   - fromBackground: Whether the app was opened from background (true) or cold start (false)
    ///   - url: The URL that opened the app, if any
    ///   - referringApp: The bundle ID of the app that referred this open, if any
    public func trackApplicationOpened(fromBackground: Bool, url: String? = nil, referringApp: String? = nil) {
        var properties: [String: Any] = [
            "from_background": fromBackground,
            "version": Self.appCurrentVersion,
            "build": Self.appCurrentBuild
        ]
        
        if let url = url {
            properties["url"] = url
        }
        
        if let referringApp = referringApp {
            properties["referring_application"] = referringApp
        }
        
        track(name: "Application Opened", properties: properties)
    }
    
    /// Tracks an Application Backgrounded event.
    public func trackApplicationBackgrounded() {
        track(name: "Application Backgrounded")
    }
    
    /// Tracks an Application Foregrounded event.
    public func trackApplicationForegrounded() {
        track(name: "Application Foregrounded")
    }
}

#if os(macOS)

extension Analytics {
    /// Tracks an Application Hidden event (macOS only).
    public func trackApplicationHidden() {
        track(name: "Application Hidden")
    }
    
    /// Tracks an Application Unhidden event (macOS only).
    /// - Parameters:
    ///   - version: The app version (defaults to current version)
    ///   - build: The app build (defaults to current build)
    public func trackApplicationUnhidden(version: String? = nil, build: String? = nil) {
        track(name: "Application Unhidden", properties: [
            "from_background": true,
            "version": version ?? Self.appCurrentVersion,
            "build": build ?? Self.appCurrentBuild
        ])
    }
    
    /// Tracks an Application Terminated event (macOS only).
    public func trackApplicationTerminated() {
        track(name: "Application Terminated")
    }
}

#endif
