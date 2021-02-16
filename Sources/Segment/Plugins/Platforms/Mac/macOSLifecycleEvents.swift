//
//  macOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

#if os(macOS)
import Cocoa

public protocol MacLifecycle {
    func applicationDidEnterBackground()
    func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?)
    func applicationWillEnterForeground()
}

public extension MacLifecycle {
    func applicationDidEnterBackground() { }
    func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?) { }
    func applicationWillEnterForeground() { }
}

class macOSLifecycleEvents: PlatformPlugin {
    static var specificName = "Segment_macOSLifecycleEvents"
    let type: PluginType
    let name: String
    let analytics: Analytics
    
    private var application: NSApplication
    private var appNotifications: [NSNotification.Name] = [NSApplication.didFinishLaunchingNotification, NSApplication.didResignActiveNotification, NSApplication.willBecomeActiveNotification]
    
    required init(name: String, analytics: Analytics) {
        self.type = .utility
        self.analytics = analytics
        self.name = name
        self.application = NSApplication.shared
    }
    
    
    @objc
    func notificationResponse(notification: NSNotification) {
        print("Notification Happened: \(notification)")
        
        switch (notification.name) {
            case NSApplication.didResignActiveNotification:
                self.didEnterBackground(notification: notification)
            case NSApplication.willBecomeActiveNotification:
                self.applicationWillEnterForeground(notification: notification)
            case NSApplication.didFinishLaunchingNotification:
                self.applicationDidFinishLaunching(notification: notification)
            default:
                break
        }
    }
    
    func setupListeners() {
        // Configure the current life cycle events
        let notificationCenter = NotificationCenter.default
        for notification in appNotifications {
            notificationCenter.addObserver(self, selector: #selector(notificationResponse(notification:)), name: notification, object: application)
        }
    }
    
    func applicationWillEnterForeground(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillEnterForeground()
            }
        }
    }
    
    func applicationDidFinishLaunching(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                let options = notification.userInfo as? [String: Any] ?? nil
                validExt.application(didFinishLaunchingWithOptions: options)
            }
        }
    }
    
    func didEnterBackground(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationDidEnterBackground()
            }
        }
    }

}

extension SegmentDestination: MacLifecycle {
    
    func applicationDidEnterBackground() {
        // TODO: Look into mac background tasks
        //analytics.beginBackgroundTask()
        flush()
    }
}
#endif
