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
        
        if activity.activityType == NSUserActivityTypeBrowsingWeb {
            if let url = activity.webpageURL {
                openURL(url, options: ["title": activity.title ?? ""])
            }
        }
    }
}

// MARK: - Opening a URL

public protocol OpeningURLs {
    func openURL(_ url: URL, options: [String : Any])
}

extension OpeningURLs {
    func openURL(_ url: URL, options: [String : Any]) {}
}

extension Analytics {
    /**
     Call openURL when instructed to by either UIApplicationDelegate or UISceneDelegate.
     This is necessary to track URL referrers across events.  This method will also iterate
     any plugins that are watching for openURL events.
     
     Example:
     ```
     <TODO>
     ```
     */
    public func openURL<T: Codable>(_ url: URL, options: T? = nil) {
        guard let jsonProperties = try? JSON(with: options) else { return }
        guard let dict = jsonProperties.dictionaryValue else { return }
        openURL(url, options: dict)
    }
    
    /**
     Call openURL when instructed to by either UIApplicationDelegate or UISceneDelegate.
     This is necessary to track URL referrers across events.  This method will also iterate
     any plugins that are watching for openURL events.
     
     Example:
     ```
     <TODO>
     ```
     */
    public func openURL(_ url: URL, options: [String: Any] = [:]) {
        store.dispatch(action: UserInfo.SetReferrerAction(url: url))
        
        // let any conforming plugins know
        apply { plugin in
            if let p = plugin as? OpeningURLs {
                p.openURL(url, options: options)
            }
        }
        
        var jsonProperties: JSON? = nil
        if let json = try? JSON(options) {
            jsonProperties = json
            _ = try? jsonProperties?.add(value: url.absoluteString, forKey: "url")
        } else {
            if let json = try? JSON(["url": url.absoluteString]) {
                jsonProperties = json
            }
        }
        track(name: "Deep Link Opened", properties: jsonProperties)
    }
}


#endif
