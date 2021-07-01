//
//  macOSUtils.swift
//  Segment
//
//  Created by Brandon Sneed on 2/24/21.
//

import Foundation

#if os(macOS) && !targetEnvironment(macCatalyst)

import WebKit
import Cocoa

extension Context {
    internal func insertStaticPlatformContextData(context: inout [String: Any]) {
        let device = ProcessInfo.processInfo
        
        // device
        // TODO: handle "token"
        context["device"] = [
            "manufacturer": "Apple",
            "type": "macos",
            "model": deviceModel(),
            "id": macAddress(bsd: "en0") ?? "", // apple suggested to use this for receipt validation in MAS, works for this too.
            "name": device.hostName
        ]
        // os
        context["os"] = [
            "name": device.operatingSystemVersionString,
            "version": String(format: "%ld.%ld.%ld",
                              device.operatingSystemVersion.majorVersion,
                              device.operatingSystemVersion.minorVersion,
                              device.operatingSystemVersion.patchVersion)
        ]
        // screen
        if let screen = NSScreen.main?.frame.size {
            context["screen"] = [
                "width": screen.width,
                "height": screen.height
            ]
        }
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
}

private func deviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
}

func macAddress(bsd : String) -> String?
{
    let MAC_ADDRESS_LENGTH = 6
    let separator = ":"

    var length : size_t = 0
    var buffer : [CChar]

    let bsdIndex = Int32(if_nametoindex(bsd))
    if bsdIndex == 0 {
        return nil
    }
    let bsdData = Data(bsd.utf8)
    var managementInfoBase = [CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, bsdIndex]

    if sysctl(&managementInfoBase, 6, nil, &length, nil, 0) < 0 {
        return nil;
    }

    buffer = [CChar](unsafeUninitializedCapacity: length, initializingWith: {buffer, initializedCount in
        for x in 0..<length { buffer[x] = 0 }
        initializedCount = length
    })

    if sysctl(&managementInfoBase, 6, &buffer, &length, nil, 0) < 0 {
        return nil;
    }

    let infoData = Data(bytes: buffer, count: length)
    let indexAfterMsghdr = MemoryLayout<if_msghdr>.stride + 1
    let rangeOfToken = infoData[indexAfterMsghdr...].range(of: bsdData)!
    let lower = rangeOfToken.upperBound
    let upper = lower + MAC_ADDRESS_LENGTH
    let macAddressData = infoData[lower..<upper]
    let addressBytes = macAddressData.map { String(format:"%02x", $0) }
    return addressBytes.joined(separator: separator)
}


#endif
