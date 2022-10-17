//
//  NotificationTracking.swift
//
//  Created by Brandon Sneed on 9/17/21.
//

// NOTE: You can see this plugin in use in the SwiftUIKitExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.

// MIT License
//
// Copyright (c) 2021 Segment
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// MARK: Common

#if !os(Linux) && !os(macOS)

import Foundation
import Segment

class NotificationTracking: Plugin {
    var type: PluginType = .utility
    weak var analytics: Analytics?
    
    func trackNotification(_ properties: [String: Any], fromLaunch launch: Bool) {
        if launch {
            analytics?.track(name: "Push Notification Tapped", properties: properties)
        } else {
            analytics?.track(name: "Push Notification Received", properties: properties)
        }
    }
}

// NOTE: watchOS doesn't have the concept of launch options for making a
// determination if a push notification caused the app to open.
extension NotificationTracking: RemoteNotifications {
    func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {
        if let notification = userInfo as? [String: Any] {
            trackNotification(notification, fromLaunch: false)
        }
    }
}

#endif

// MARK: macOS -- TODO: Full lifecycle/delegation options in library.
/*
#if os(macOS)

import Cocoa

extension NotificationTracking: macOSLifecycle {
    func application(didFinishLaunchingWithOptions launchOptions: [String: Any]?) {
        if let notification = launchOptions?[NSApplication.launchUserNotificationUserInfoKey] as? [String: Any] {
            trackNotification(notification, fromLaunch: true)
        }
    }
}

#endif
*/

// MARK: iOS/tvOS/Catalyst

#if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)

import UIKit

extension NotificationTracking: iOSLifecycle {
    func application(_ application: UIApplication?, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        if let notification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Any] {
            trackNotification(notification, fromLaunch: true)
        }
    }
}

#endif

