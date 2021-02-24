//
//  iOSUtils.swift
//  Segment
//
//  Created by Brandon Sneed on 2/24/21.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)

import UIKit
import WebKit
import SystemConfiguration

func insertStaticPlatformContextData(context: inout [String: Any]) {
    let device = UIDevice.current
    
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
    let userAgent = WKWebView().value(forKey: "userAgent")
    context["userAgent"] = userAgent
    // locale
    if Locale.preferredLanguages.count > 0 {
        context["locale"] = Locale.preferredLanguages[0]
    }
    // timezone
    context["timezone"] = TimeZone.current.identifier
}

func insertDynamicPlatformContextData(context: inout [String: Any]) {
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

private enum ReachabilityType {
    case cellular
    case wifi
}

private enum ReachabilityStatus {
    case offline
    case online(ReachabilityType)
    case unknown
    
    init(reachabilityFlags flags: SCNetworkReachabilityFlags) {
        let connectionRequired = flags.contains(.connectionRequired)
        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)

        if !connectionRequired && isReachable {
            if isWWAN {
                self = .online(.cellular)
            } else {
                self = .online(.wifi)
            }
        } else {
            self =  .offline
        }
    }
}

private func connectionStatus() -> ReachabilityStatus {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)

    guard let defaultRouteReachability = (withUnsafePointer(to: &zeroAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
            SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
        }
    }) else {
       return .unknown
    }

    var flags : SCNetworkReachabilityFlags = []
    if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
        return .unknown
    }

    return ReachabilityStatus(reachabilityFlags: flags)
}

#endif
