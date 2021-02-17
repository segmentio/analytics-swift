//
//  macOSLifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

#if os(macOS)
import Cocoa

public protocol MacLifecycle {
    func applicationDidResignActive()
    func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?)
    func applicationWillBecomeActive()
    func applicationDidBecomeActive()
    func applicationWillHide()
    func applicationDidHide()
    func applicationDidUnhide()
    func applicationDidUpdate()
    func applicationWillFinishLaunching()
    func applicationWillResignActive()
    func applicationWillUnhide()
    func applicationWillUpdate()
    func applicationWillTerminate()
    func applicationDidChangeScreenParameters()
}

public extension MacLifecycle {
    func applicationDidResignActive() { }
    func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?) { }
    func applicationWillBecomeActive() { }
    func applicationDidBecomeActive() { }
    func applicationWillHide() { }
    func applicationDidHide() { }
    func applicationDidUnhide() { }
    func applicationDidUpdate() { }
    func applicationWillFinishLaunching() { }
    func applicationWillResignActive() { }
    func applicationWillUnhide() { }
    func applicationWillUpdate() { }
    func applicationWillTerminate() { }
    func applicationDidChangeScreenParameters() { }
}

class macOSLifecycleEvents: PlatformPlugin {
    static var specificName = "Segment_macOSLifecycleEvents"
    let type: PluginType
    let name: String
    let analytics: Analytics
    
    private var application: NSApplication
    private var appNotifications: [NSNotification.Name] =
        [NSApplication.didFinishLaunchingNotification,
         NSApplication.didResignActiveNotification,
         NSApplication.willBecomeActiveNotification,
         NSApplication.didBecomeActiveNotification,
         NSApplication.didHideNotification,
         NSApplication.didUnhideNotification,
         NSApplication.didUpdateNotification,
         NSApplication.willHideNotification,
         NSApplication.willFinishLaunchingNotification,
         NSApplication.willResignActiveNotification,
         NSApplication.willUnhideNotification,
         NSApplication.willUpdateNotification,
         NSApplication.willTerminateNotification,
         NSApplication.didChangeScreenParametersNotification]
    
    required init(name: String, analytics: Analytics) {
        self.type = .utility
        self.analytics = analytics
        self.name = name
        self.application = NSApplication.shared
        
        setupListeners()
    }
    
    
    @objc
    func notificationResponse(notification: NSNotification) {
        print("Notification Happened: \(notification)")
        
        switch (notification.name) {
            case NSApplication.didResignActiveNotification:
                self.didResignActive(notification: notification)
            case NSApplication.willBecomeActiveNotification:
                self.applicationWillBecomeActive(notification: notification)
            case NSApplication.didFinishLaunchingNotification:
                self.applicationDidFinishLaunching(notification: notification)
            case NSApplication.didBecomeActiveNotification:
                self.applicationDidBecomeActive(notification: notification)
            case NSApplication.didHideNotification:
                self.applicationDidHide(notification: notification)
            case NSApplication.didUnhideNotification:
                self.applicationDidUnhide(notification: notification)
            case NSApplication.didUpdateNotification:
                self.applicationDidUpdate(notification: notification)
            case NSApplication.willHideNotification:
                self.applicationWillHide(notification: notification)
            case NSApplication.willFinishLaunchingNotification:
                self.applicationWillFinishLaunching(notification: notification)
            case NSApplication.willResignActiveNotification:
                self.applicationWillResignActive(notification: notification)
            case NSApplication.willUnhideNotification:
                self.applicationWillUnhide(notification: notification)
            case NSApplication.willUpdateNotification:
                self.applicationWillUpdate(notification: notification)
            case NSApplication.willTerminateNotification:
                self.applicationWillTerminate(notification: notification)
            case NSApplication.didChangeScreenParametersNotification:
                self.applicationDidChangeScreenParameters(notification: notification)
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
    
    func applicationWillBecomeActive(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillBecomeActive()
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
    
    func didResignActive(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationDidResignActive()
            }
        }
    }
    
    func applicationDidBecomeActive(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationDidBecomeActive()
            }
        }
    }
    
    func applicationDidHide(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationDidHide()
            }
        }
    }
    
    func applicationDidUnhide(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationDidUnhide()
            }
        }
    }

    func applicationDidUpdate(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationDidUpdate()
            }
        }
    }
    
    func applicationWillHide(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillHide()
            }
        }
    }
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillFinishLaunching()
            }
        }
    }
    
    func applicationWillResignActive(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillResignActive()
            }
        }
    }
    
    func applicationWillUnhide(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillUnhide()
            }
        }
    }
    
    func applicationWillUpdate(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillUpdate()
            }
        }
    }
    
    func applicationWillTerminate(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationWillTerminate()
            }
        }
    }
    
    func applicationDidChangeScreenParameters(notification: NSNotification) {
        analytics.apply { (ext) in
            if let validExt = ext as? MacLifecycle {
                validExt.applicationDidChangeScreenParameters()
            }
        }
    }
}

extension SegmentDestination: MacLifecycle {
    
    public func applicationDidEnterBackground() {
        // TODO: Look into mac background tasks
        //analytics.beginBackgroundTask()
        flush()
    }
}
#endif
