//
//  LifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 12/8/20.
//

import Foundation


// MARK: - iOS Platform Lifecycle

#if os(iOS)
import UIKit

protocol iOSLifecycle {
    func applicationDidEnterBackground(application: UIApplication)
    func applicationWillEnterForeground(application: UIApplication)
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func applicationDidBecomeActive(application: UIApplication)
    func applicationWillResignActive(application: UIApplication)
    func applicationDidReceiveMemoryWarning(application: UIApplication)
    func applicationWillTerminate(application: UIApplication)
    func applicationSignificantTimeChange(application: UIApplication)
    func applicationBackgroundRefreshDidChange(application: UIApplication, refreshStatus: UIBackgroundRefreshStatus)
}
#endif


// MARK: - Analytics Lifecycle passthru methods

extension Analytics {
    func receivedRemoteNotification(userInfo: Dictionary<String, Codable>) {
        // ...
    }
    
    func failedToRegisterForRemoteNotificationsWithError(error: Error) {
        // ...
    }
    
    func registeredForRemoteNotificationsWithDeviceToken(deviceToken: Data) {
        // ...
    }
    
    // Deprecated in iOS 10 -- look at UserNotifications Framework
    func handleActionWithIdentifier(identifier: String, remoteNotification: Dictionary<String, Codable>) {
        // ...
        // Possibly pass as [UNUserNotificationCenterDelegate didReceiveNotificationResponse:withCompletionHandler:]
    }
    
    func continueUserActivity(activity: NSUserActivity) {
        // ...
    }
    
    func openURL(url: NSURL, options: Dictionary<String, Any>) {
        // ...
    }
}
