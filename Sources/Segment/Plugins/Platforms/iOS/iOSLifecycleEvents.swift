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
    let type = PluginType.before
    weak var analytics: Analytics?
    
    @Atomic private var didFinishLaunching = false
    @Atomic private var wasBackgrounded = false
    @Atomic private var didCheckInstallOrUpdate = false
    
    func configure(analytics: Analytics) {
        self.analytics = analytics
        
        // Check install/update immediately to catch first launch
        if !didCheckInstallOrUpdate {
            analytics.checkAndTrackInstallOrUpdate()
            _didCheckInstallOrUpdate.set(true)
        }
    }
    
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        _didFinishLaunching.set(true)

        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            let sourceApp = launchOptions?[.sourceApplication] as? String ?? ""
            let url = urlFrom(launchOptions)
            
            analytics?.trackApplicationOpened(fromBackground: false, url: url.isEmpty ? nil : url, referringApp: sourceApp.isEmpty ? nil : sourceApp)
        }
    }
    
    func applicationWillEnterForeground(application: UIApplication?) {
        if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) == true {
            if didFinishLaunching == false {
                analytics?.trackApplicationOpened(fromBackground: true)
            }
        }
        
        // Only fire if we were actually backgrounded
        if wasBackgrounded {
            if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationForegrounded) == true {
                analytics?.trackApplicationForegrounded()
            }
            _wasBackgrounded.set(false)
        }
    }
    
    func applicationDidEnterBackground(application: UIApplication?) {
        _didFinishLaunching.set(false)
        if !wasBackgrounded {
            _wasBackgrounded.set(true)
            
            if analytics?.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationBackgrounded) == true {
                analytics?.trackApplicationBackgrounded()
            }
        }
    }
    
    func applicationDidBecomeActive(application: UIApplication?) {
        // DO NOT USE THIS.
    }
    
    private func urlFrom(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> String {
        if let url = launchOptions?[.url] as? String {
            return url
        }
        if let url = launchOptions?[.url] as? NSURL, let rawUrl = url.absoluteString {
            return rawUrl
        }
        return ""
    }
}

#endif
