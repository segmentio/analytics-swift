//
//  watchOSDelegation.swift
//  
//
//  Created by Brandon Sneed on 6/24/21.
//

#if os(watchOS)

import Foundation
import WatchKit

// MARK: - Remote Notifications

public protocol RemoteNotifications: Plugin {
    func registeredForRemoteNotifications(deviceToken: Data)
    func failedToRegisterForRemoteNotification(error: Error?)
    func receivedRemoteNotification(userInfo: [AnyHashable: Any])
}

extension RemoteNotifications {
    public func registeredForRemoteNotifications(deviceToken: Data) {}
    public func failedToRegisterForRemoteNotification(error: Error?) {}
    public func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {}
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

}

#endif
