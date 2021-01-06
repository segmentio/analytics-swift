//
//  Lifecycle.swift
//  Segment
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation

// Users can call these methods as needed/desired.
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


