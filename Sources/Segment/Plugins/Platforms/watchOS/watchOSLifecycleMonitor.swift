//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/24/21.
//

#if os(watchOS)

import Foundation
import WatchKit

public protocol watchOSLifecycle {
    func applicationDidFinishLaunching(watchExtension: WKExtension)
    func applicationWillEnterForeground(watchExtension: WKExtension)
    func applicationDidEnterBackground(watchExtension: WKExtension)
    func applicationDidBecomeActive(watchExtension: WKExtension)
    func applicationWillResignActive(watchExtension: WKExtension)
}

public extension watchOSLifecycle {
    func applicationDidFinishLaunching(watchExtension: WKExtension) { }
    func applicationWillEnterForeground(watchExtension: WKExtension) { }
    func applicationDidEnterBackground(watchExtension: WKExtension) { }
    func applicationDidBecomeActive(watchExtension: WKExtension) { }
    func applicationWillResignActive(watchExtension: WKExtension) { }
}


class watchOSLifecycleMonitor: PlatformPlugin {
    let type = PluginType.utility
    weak var analytics: Analytics?
    var wasBackgrounded: Bool = false
    
    private var watchExtension = WKExtension.shared()
    private var appNotifications: [NSNotification.Name] = [WKExtension.applicationDidFinishLaunchingNotification,
                                                           WKExtension.applicationWillEnterForegroundNotification,
                                                           WKExtension.applicationDidEnterBackgroundNotification,
                                                           WKExtension.applicationDidBecomeActiveNotification,
                                                           WKExtension.applicationWillResignActiveNotification]
    
    required init() {
        watchExtension = WKExtension.shared()
        setupListeners()
    }
    
    @objc
    func notificationResponse(notification: NSNotification) {
        switch (notification.name) {
        case WKExtension.applicationDidFinishLaunchingNotification:
            self.applicationDidFinishLaunching(notification: notification)
        case WKExtension.applicationWillEnterForegroundNotification:
            self.applicationWillEnterForeground(notification: notification)
        case WKExtension.applicationDidEnterBackgroundNotification:
            self.applicationDidEnterBackground(notification: notification)
        case WKExtension.applicationDidBecomeActiveNotification:
            self.applicationDidBecomeActive(notification: notification)
        case WKExtension.applicationWillResignActiveNotification:
            self.applicationWillResignActive(notification: notification)
        default:
            break
        }
    }
    
    func setupListeners() {
        // Configure the current life cycle events
        let notificationCenter = NotificationCenter.default
        for notification in appNotifications {
            notificationCenter.addObserver(self, selector: #selector(notificationResponse(notification:)), name: notification, object: nil)
        }
    }
    
    func applicationDidFinishLaunching(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? watchOSLifecycle {
                validExt.applicationDidFinishLaunching(watchExtension: watchExtension)
            }
        }
    }
    
    func applicationWillEnterForeground(notification: NSNotification) {
        // watchOS will receive this after didFinishLaunching, which is different
        // from iOS, so ignore until we've been backgrounded at least once.
        if wasBackgrounded == false { return }
        
        analytics?.apply { (ext) in
            if let validExt = ext as? watchOSLifecycle {
                validExt.applicationWillEnterForeground(watchExtension: watchExtension)
            }
        }
    }
    
    func applicationDidEnterBackground(notification: NSNotification) {
        // make sure to denote that we were backgrounded.
        wasBackgrounded = true
        
        analytics?.apply { (ext) in
            if let validExt = ext as? watchOSLifecycle {
                validExt.applicationDidEnterBackground(watchExtension: watchExtension)
            }
        }
    }
    
    func applicationDidBecomeActive(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? watchOSLifecycle {
                validExt.applicationDidBecomeActive(watchExtension: watchExtension)
            }
        }
    }
    
    func applicationWillResignActive(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? watchOSLifecycle {
                validExt.applicationWillResignActive(watchExtension: watchExtension)
            }
        }
    }

}

// MARK: - Segment Destination Extension

extension SegmentDestination: watchOSLifecycle {
    public func applicationWillEnterForeground(watchExtension: WKExtension) {
        enterForeground()
    }
    
    public func applicationDidEnterBackground(watchExtension: WKExtension) {
        enterBackground()
    }
}

#endif
