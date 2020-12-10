//
//  LifecycleEvents.swift
//  Segment
//
//  Created by Cody Garvin on 12/4/20.
//

#if os(iOS) || os(watchOS) || os(tvOS)

import Foundation
import UIKit

class iOSLifeCycleEvents: Extension {
    let type: ExtensionType
    let name: String
    
    var analytics: Analytics? = nil
    
    private var application: UIApplication
    private var appNotifications: [NSNotification.Name] = [UIApplication.didEnterBackgroundNotification,
                                                           UIApplication.willEnterForegroundNotification,
                                                           UIApplication.didFinishLaunchingNotification,
                                                           UIApplication.didBecomeActiveNotification,
                                                           UIApplication.willResignActiveNotification,
                                                           UIApplication.didReceiveMemoryWarningNotification,
                                                           UIApplication.willTerminateNotification,
                                                           UIApplication.significantTimeChangeNotification,
                                                           UIApplication.backgroundRefreshStatusDidChangeNotification]
    
    

    required init(name: String) {
        self.type = .before
        self.name = name
        application = UIApplication.shared
        
        setupListeners()

    }
    
    @objc
    func notificationResponse(notification: NSNotification) {
        print("Notification Happened: \(notification)")
        
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
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillEnterForeground(application: application)
            }
        }
    }
    
    func didEnterBackground(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationDidEnterBackground(application: application)
            }
        }
    }
    
    func didFinishLaunching(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                let options = notification.userInfo as? [UIApplication.LaunchOptionsKey: Any] ?? nil
                validExt.application(application, didFinishLaunchingWithOptions: options)
            }
        }
    }

    func didBecomeActive(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationDidBecomeActive(application: application)
            }
        }
    }
    
    func willResignActive(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillResignActive(application: application)
            }
        }
    }
    
    func didReceiveMemoryWarning(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationDidReceiveMemoryWarning(application: application)
            }
        }
    }
    
    func willTerminate(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillTerminate(application: application)
            }
        }
    }
    
    func significantTimeChange(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationSignificantTimeChange(application: application)
            }
        }
    }
    
    func backgroundRefreshDidChange(notification: NSNotification) {
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationBackgroundRefreshDidChange(application: application,
                                                               refreshStatus: application.backgroundRefreshStatus)
            }
        }
    }
}

#endif
