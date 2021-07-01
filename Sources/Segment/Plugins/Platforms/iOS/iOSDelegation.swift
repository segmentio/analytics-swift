//
//  iOSDelegation.swift
//  Segment
//
//  Created by Brandon Sneed on 4/7/21.
//

import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import UIKit

// MARK: - Remote Notifications

public protocol RemoteNotifications: Plugin {
    func registeredForRemoteNotifications(deviceToken: Data)
    func failedToRegisterForRemoteNotification(error: Error?)
    func receivedRemoteNotification(userInfo: [AnyHashable: Any])
    func handleAction(identifier: String, userInfo: [String: Any])
}

extension RemoteNotifications {
    public func registeredForRemoteNotifications(deviceToken: Data) {}
    public func failedToRegisterForRemoteNotification(error: Error?) {}
    public func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {}
    public func handleAction(identifier: String, userInfo: [String: Any]) {}
}

extension Analytics {
    public func registeredForRemoteNotifications(deviceToken: Data) {
        setDeviceToken(deviceToken.hexString)
        
        apply { plugin in
            if let p = plugin as? RemoteNotifications {
                p.registeredForRemoteNotifications(deviceToken: deviceToken)
            }
        }
    }
    
    public func failedToRegisterForRemoteNotification(error: Error?) {
        apply { plugin in
            if let p = plugin as? RemoteNotifications {
                p.failedToRegisterForRemoteNotification(error: error)
            }
        }
    }
    
    public func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {
        apply { plugin in
            if let p = plugin as? RemoteNotifications {
                p.receivedRemoteNotification(userInfo: userInfo)
            }
        }
    }
    
    public func handleAction(identifier: String, userInfo: [String: Any]) {
        apply { plugin in
            if let p = plugin as? RemoteNotifications {
                p.handleAction(identifier: identifier, userInfo: userInfo)
            }
        }
    }
}

// MARK: - User Activity

public protocol UserActivities {
    func continueUserActivity(_ activity: NSUserActivity)
}

extension UserActivities {
    func continueUserActivity(_ activity: NSUserActivity) {}
}

extension Analytics {
    public func continueUserActivity(_ activity: NSUserActivity) {
        apply { plugin in
            if let p = plugin as? UserActivities {
                p.continueUserActivity(activity)
            }
        }
    }
}

// MARK: - Opening a URL

public protocol OpeningURLs {
    func openURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey : Any])
}

extension OpeningURLs {
    func openURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) {}
}

extension Analytics {
    public func openURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) {
        apply { plugin in
            if let p = plugin as? OpeningURLs {
                p.openURL(url, options: options)
            }
        }
    }
}

#endif
