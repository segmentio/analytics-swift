//
//  LifecycleEvents.swift
//  Segment
//
//  Created by Cody Garvin on 12/4/20.
//

import Foundation
#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit

//protocol iOSLifeCycleCoordinator: ExtensionCoordinator {
//    func didEnterBackgroundNotification()
//}

//extension iOSLifeCycleCoordinator {
//    func didEnterBackgroundNotification() { }
//}

class iOSLifeCycleEvents: Extension  {
    
    var type: ExtensionType
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
    
    

    required init(type: ExtensionType) {
        self.type = type // needs to be before
        application = UIApplication.shared
        
        setupListeners()

    }
    
    @objc
    func notificationResponse(notification: NSNotification) {
        print("Notification Happened: \(notification)")
        
        
        
    }
    
    internal func addResponder() {
        
    }
    
    internal func removeResponder() {
        
    }
    
    func setupListeners() {
        // do all your subscription to lifecycle shit here
        // .. listener ends up calling appicationDidFinishLaunching
        // Configure the current life cycle events
        let notificationCenter = NotificationCenter.default
        for notification in appNotifications {
            notificationCenter.addObserver(self, selector: #selector(notificationResponse(notification:)), name: notification, object: application)
        }

    }
    
    func applicationDidFinishLaunching(notification: Notification) {
        // ... deconstruct it ...
        
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillEnterForeground(application: application)
            }
        }
    }
    
}

#endif
