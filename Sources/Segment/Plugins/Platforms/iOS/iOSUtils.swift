//
//  iOSUtils.swift
//  Segment
//
//  Created by Brandon Sneed on 2/24/21.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS) || targetEnvironment(macCatalyst)

import UIKit

// webkit not available on iOS
#if !os(watchOS)
import WebKit
#else
import WatchKit
#endif

internal func insertStaticPlatformContextData(context: inout [String: Any]) {
    #if os(watchOS)
    let device = WKInterfaceDevice.current()
    #else
    let device = UIDevice.current
    #endif
    
    // device
    // TODO: handle "token"
    context["device"] = [
        "manufacturer": "Apple",
        "type": "ios",
        "model": "",
        "id": device.identifierForVendor?.uuidString ?? ""
    ]
    // os
    context["os"] = [
        "name": device.systemName,
        "version": device.systemVersion
    ]
    // screen
    let screen = UIScreen.main.bounds.size
    context["screen"] = [
        "width": screen.width,
        "height": screen.height
    ]
    // user-agent
    #if !os(watchOS)
    let userAgent = WKWebView().value(forKey: "userAgent")
    context["userAgent"] = userAgent
    #endif
    // locale
    if Locale.preferredLanguages.count > 0 {
        context["locale"] = Locale.preferredLanguages[0]
    }
    // timezone
    context["timezone"] = TimeZone.current.identifier
}

internal func insertDynamicPlatformContextData(context: inout [String: Any]) {
    // network
    let status = connectionStatus()
    
    var cellular = false
    var wifi = false
    
    switch status {
    case .online(.cellular):
        cellular = true
    case .online(.wifi):
        wifi = true
    default:
        break
    }
    
    context["network"] = [
        "bluetooth": false, // ios doesn't really support bluetooth network, does it??
        "cellular": cellular,
        "wifi": wifi
    ]
    
    // other stuff?? ...
}

#endif
