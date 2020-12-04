//
//  Analytics.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation
import Sovran

protocol EdgeFunctionMiddleware {
    // This is a stub
}

// Initial creation
public class Analytics {
    internal var configuration: Configuration
    internal let timeline = Timeline()
    
    // this should be in State->System
    //private var isEnabled = true
    
    /// Enabled/disables debug logging to trace your data going through the SDK.
    public var debugLogsEnabled = false

    
    init(writeKey: String) {
        configuration = Configuration(writeKey: writeKey)
    }
    
    internal init(config: Configuration) {
        configuration = config
    }
    
    func build() -> Analytics {
        return Analytics(config: configuration)
    }
}

// Utilities
extension Analytics {
    
    func flush() {
        // ...
    }
    
    func reset() {
        // ...
    }
    
    func version() -> Int {
        // ...
        return 0
    }
    
    func anonymousId() -> String {
        // ??? not getAnonymousId
        return ""
    }
    
    func deviceToken() -> String {
        // ??? not getDeviceToken
        return ""
    }
    
    func edgeFunction() -> EdgeFunctionMiddleware? {
        return nil
    }
}

// Lifecycle passthru methods
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

// Deprecations
extension Analytics {
    @available(*, deprecated)
    func enable() {
        
    }
    
    @available(*, deprecated)
    func disable() {
        
    }
}
