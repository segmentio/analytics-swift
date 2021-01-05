//
//  Lifecycle.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation

extension Analytics {
    internal func setupLifecycleChecking(analytics: Analytics) {
        #if os(iOS) || os(watchOS) || os(tvOS)
        let lifecycle = iOSLifecycleEvents(name: "Segment_iOSLifecycleExtension", analytics: self)
        #endif
        #if os(macOS)
        let lifecycle = macOSLifecycleEvents(name: "Segment_macOSLifecycleExtension", analytics: self)
        #endif
        #if os(Linux)
        let lifecycle = LinuxLifecycleEvents(name: "Segment_LinuxLifecycleExtension", analytics: self)
        #endif
        lifecycle.analytics = analytics
        analytics.extensions.add(lifecycle)
    }
}

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


