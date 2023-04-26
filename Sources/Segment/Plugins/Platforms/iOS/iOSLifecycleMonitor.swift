//
//  LifecycleEvents.swift
//  Segment
//
//  Created by Cody Garvin on 12/4/20.
//

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Foundation
import UIKit

// NOTE: These method signatures are marked optional as application extensions may not have
// a UIApplication object available.  See `safeShared` below.
public protocol iOSLifecycle {
    func applicationDidEnterBackground(application: UIApplication?)
    func applicationWillEnterForeground(application: UIApplication?)
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func applicationDidBecomeActive(application: UIApplication?)
    func applicationWillResignActive(application: UIApplication?)
    func applicationDidReceiveMemoryWarning(application: UIApplication?)
    func applicationWillTerminate(application: UIApplication?)
    func applicationSignificantTimeChange(application: UIApplication?)
    func applicationBackgroundRefreshDidChange(application: UIApplication?, refreshStatus: UIBackgroundRefreshStatus)
}

public extension iOSLifecycle {
    func applicationDidEnterBackground(application: UIApplication?) { }
    func applicationWillEnterForeground(application: UIApplication?) { }
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) { }
    func applicationDidBecomeActive(application: UIApplication?) { }
    func applicationWillResignActive(application: UIApplication?) { }
    func applicationDidReceiveMemoryWarning(application: UIApplication?) { }
    func applicationWillTerminate(application: UIApplication?) { }
    func applicationSignificantTimeChange(application: UIApplication?) { }
    func applicationBackgroundRefreshDidChange(application: UIApplication?, refreshStatus: UIBackgroundRefreshStatus) { }
}

class iOSLifecycleMonitor: PlatformPlugin {
    let type = PluginType.utility
    weak var analytics: Analytics?
    
    private var application: UIApplication? = nil
    private var appNotifications: [NSNotification.Name] = [UIApplication.didEnterBackgroundNotification,
                                                           UIApplication.willEnterForegroundNotification,
                                                           UIApplication.didFinishLaunchingNotification,
                                                           UIApplication.didBecomeActiveNotification,
                                                           UIApplication.willResignActiveNotification,
                                                           UIApplication.didReceiveMemoryWarningNotification,
                                                           UIApplication.willTerminateNotification,
                                                           UIApplication.significantTimeChangeNotification,
                                                           UIApplication.backgroundRefreshStatusDidChangeNotification]

    required init() {
        // App extensions can't use UIAppication.shared, so
        // funnel it through something to check; Could be nil.
        application = UIApplication.safeShared
        setupListeners()
    }
    
    @objc
    func notificationResponse(notification: NSNotification) {        
        switch (notification.name) {
        case UIApplication.didEnterBackgroundNotification:
            self.didEnterBackground(notification: notification)
        case UIApplication.willEnterForegroundNotification:
            self.applicationWillEnterForeground(notification: notification)
        case UIApplication.didFinishLaunchingNotification:
            self.didFinishLaunching(notification: notification)
        case UIApplication.didBecomeActiveNotification:
            self.didBecomeActive(notification: notification)
        case UIApplication.willResignActiveNotification:
            self.willResignActive(notification: notification)
        case UIApplication.didReceiveMemoryWarningNotification:
            self.didReceiveMemoryWarning(notification: notification)
        case UIApplication.significantTimeChangeNotification:
            self.significantTimeChange(notification: notification)
        case UIApplication.backgroundRefreshStatusDidChangeNotification:
            self.backgroundRefreshDidChange(notification: notification)
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
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillEnterForeground(application: application)
            }
        }
    }
    
    func didEnterBackground(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationDidEnterBackground(application: application)
            }
        }
    }
    
    func didFinishLaunching(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                let options = notification.userInfo as? [UIApplication.LaunchOptionsKey: Any] ?? nil
                validExt.application(application, didFinishLaunchingWithOptions: options)
            }
        }
    }

    func didBecomeActive(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationDidBecomeActive(application: application)
            }
        }
    }
    
    func willResignActive(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillResignActive(application: application)
            }
        }
    }
    
    func didReceiveMemoryWarning(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationDidReceiveMemoryWarning(application: application)
            }
        }
    }
    
    func willTerminate(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillTerminate(application: application)
            }
        }
    }
    
    func significantTimeChange(notification: NSNotification) {
        analytics?.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationSignificantTimeChange(application: application)
            }
        }
    }
    
    func backgroundRefreshDidChange(notification: NSNotification) {
        // Not only would we not get this in an App Extension, but it would
        // be useless since we couldn't provide the application object or
        // the refreshStatus value.
        if !isAppExtension, let application = UIApplication.safeShared {
            analytics?.apply { (ext) in
                if let validExt = ext as? iOSLifecycle {
                    validExt.applicationBackgroundRefreshDidChange(application: application,
                                                                   refreshStatus: application.backgroundRefreshStatus)
                }
            }
        }
    }
}

// MARK: - Segment Destination Extension


extension SegmentDestination: iOSLifecycle {
    public func applicationWillEnterForeground(application: UIApplication?) {
        enterForeground()
    }
    
    public func applicationDidEnterBackground(application: UIApplication?) {
        enterBackground()
    }
}

extension SegmentDestination.UploadTaskInfo {
    init(url: URL, task: URLSessionDataTask) {
        self.url = url
        self.task = task
        
        if let application = UIApplication.safeShared {
            var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
            taskIdentifier = application.beginBackgroundTask {
                task.cancel()
                application.endBackgroundTask(taskIdentifier)
            }
            
            self.cleanup = {
                application.endBackgroundTask(taskIdentifier)
            }
        }
    }
}

// MARK: - Interval Based Flush Policy Extension

extension IntervalBasedFlushPolicy: iOSLifecycle {
    public func applicationWillEnterForeground(application: UIApplication?) {
        enterForeground()
    }
    
    public func applicationDidEnterBackground(application: UIApplication?) {
        enterBackground()
    }
}

extension UIApplication {
    static var safeShared: UIApplication? {
        // UIApplication.shared is not available in app extensions so try to get
        // it in a way that's safe for both.
        
        // if we are NOT an app extension, we need to get UIApplication.shared
        if !isAppExtension {
            // getting it like this allows us to avoid the compiler error that would
            // be generated even though we're guarding against app extensions.
            // there's no preprocessor macro or @available macro to help us here unfortunately
            // so this is the best i could do.
            return UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication
        }
        // if we ARE an app extension, send back nil since we have no way to get the
        // application instance.
        return nil
    }
}

#endif
