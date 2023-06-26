//
//  AppleUtils.swift
//  Segment
//
//  Created by Brandon Sneed on 2/26/21.
//

import Foundation

// MARK: - iOS, tvOS, Catalyst

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import SystemConfiguration
import UIKit
#if !os(tvOS)
import WebKit
#endif

internal class iOSVendorSystem: VendorSystem {
    private let device = UIDevice.current
    @Atomic private static var asyncUserAgent: String? = nil
    
    override var manufacturer: String {
        return "Apple"
    }
    
    override var type: String {
        #if os(iOS)
        return "ios"
        #elseif os(tvOS)
        return "tvos"
        #elseif targetEnvironment(macCatalyst)
        return "macos"
        #else
        return "unknown"
        #endif
    }
    
    override var model: String {
        // eg. "iPhone5,1"
        return deviceModel()
    }
    
    override var name: String {
        // eg. "iPod Touch"
        return device.model
    }
    
    override var identifierForVendor: String? {
        return device.identifierForVendor?.uuidString
    }
    
    override var systemName: String {
        return device.systemName
    }
    
    override var systemVersion: String {
        device.systemVersion
    }
    
    override var screenSize: ScreenSize {
        let screenSize = UIScreen.main.bounds.size
        return ScreenSize(width: Double(screenSize.width), height: Double(screenSize.height))
    }
    
    override var userAgent: String? {
        #if !os(tvOS)
        // BKS: It was discovered that on some platforms there can be a delay in retrieval.
        // It has to be fetched on the main thread, so we've spun it off
        // async and cache it when it comes back.
        if Self.asyncUserAgent == nil {
            DispatchQueue.main.async {
                Self.asyncUserAgent = WKWebView().value(forKey: "userAgent") as? String
            }
        }
        return Self.asyncUserAgent
        #else
        // webkit isn't on tvos
        return "unknown"
        #endif
    }
    
    override var connection: ConnectionStatus {
        return connectionStatus()
    }
    
    override var requiredPlugins: [PlatformPlugin] {
        return [iOSLifecycleMonitor(), DeviceToken()]
    }
    
    private func deviceModel() -> String {
        var name: [Int32] = [CTL_HW, HW_MACHINE]
        var size: Int = 2
        sysctl(&name, 2, nil, &size, nil, 0)
        var hw_machine = [CChar](repeating: 0, count: Int(size))
        sysctl(&name, 2, &hw_machine, &size, nil, 0)
        let model = String(cString: hw_machine)
        return model
    }
}

#endif

// MARK: - watchOS

#if os(watchOS)

import WatchKit
import Network

internal class watchOSVendorSystem: VendorSystem {
    private let device = WKInterfaceDevice.current()
    
    override var manufacturer: String {
        return "Apple"
    }
    
    override var type: String {
        return "watchos"
    }
    
    override var model: String {
        return deviceModel()
    }
    
    override var name: String {
        return device.model
    }
    
    override var identifierForVendor: String? {
        return device.identifierForVendor?.uuidString
    }
    
    override var systemName: String {
        return device.systemName
    }
    
    override var systemVersion: String {
        device.systemVersion
    }
    
    override var screenSize: ScreenSize {
        let screenSize = device.screenBounds.size
        return ScreenSize(width: Double(screenSize.width), height: Double(screenSize.height))
    }
    
    override var userAgent: String? {
        return nil
    }
    
    override var connection: ConnectionStatus {
        let path = NWPathMonitor().currentPath
        let interfaces = path.availableInterfaces
        
        var cellular = false
        var wifi = false
        for interface in interfaces {
            if interface.type == .cellular {
                cellular = true
            } else if interface.type == .wifi {
                wifi = true
            }
        }
        if cellular {
            return ConnectionStatus.online(.cellular)
        } else if wifi {
            return ConnectionStatus.online(.wifi)
        }
        return ConnectionStatus.unknown
    }
    
    override var requiredPlugins: [PlatformPlugin] {
        return [watchOSLifecycleMonitor(), DeviceToken()]
    }
    
    private func deviceModel() -> String {
        var name: [Int32] = [CTL_HW, HW_MACHINE]
        var size: Int = 2
        sysctl(&name, 2, nil, &size, nil, 0)
        var hw_machine = [CChar](repeating: 0, count: Int(size))
        sysctl(&name, 2, &hw_machine, &size, nil, 0)
        let model = String(cString: hw_machine)
        return model
    }

}

#endif

// MARK: - macOS

#if os(macOS)

import Cocoa
import WebKit

internal class MacOSVendorSystem: VendorSystem {
    private let device = ProcessInfo.processInfo
    @Atomic private static var asyncUserAgent: String? = nil
    
    override var manufacturer: String {
        return "Apple"
    }
    
    override var type: String {
        return "macos"
    }
    
    override var model: String {
        return deviceModel()
    }
    
    override var name: String {
        return device.hostName
    }
    
    override var identifierForVendor: String? {
        // apple suggested to use this for receipt validation
        // in MAS, works for this too.
        return macAddress(bsd: "en0")
    }
    
    override var systemName: String {
        return "macOS"
    }
    
    override var systemVersion: String {
        return String(format: "%ld.%ld.%ld",
                      device.operatingSystemVersion.majorVersion,
                      device.operatingSystemVersion.minorVersion,
                      device.operatingSystemVersion.patchVersion)
    }
    
    override var screenSize: ScreenSize {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 0, height: 0)
        return ScreenSize(width: Double(screenSize.width), height: Double(screenSize.height))
    }
    
    override var userAgent: String? {
        // BKS: It was discovered that on some platforms there can be a delay in retrieval.
        // It has to be fetched on the main thread, so we've spun it off
        // async and cache it when it comes back.
        if Self.asyncUserAgent == nil {
            DispatchQueue.main.async {
                Self.asyncUserAgent = WKWebView().value(forKey: "userAgent") as? String
            }
        }
        return Self.asyncUserAgent
    }
    
    override var connection: ConnectionStatus {
        return connectionStatus()
    }
    
    override var requiredPlugins: [PlatformPlugin] {
        return [macOSLifecycleMonitor(), DeviceToken()]
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

    private func macAddress(bsd : String) -> String? {
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
}

#endif

// MARK: - Reachability

#if os(iOS) || os(tvOS) || os(macOS) || targetEnvironment(macCatalyst)

#if os(macOS)
import SystemConfiguration
#endif

extension ConnectionStatus {
    init(reachabilityFlags flags: SCNetworkReachabilityFlags) {
        let connectionRequired = flags.contains(.connectionRequired)
        let isReachable = flags.contains(.reachable)
        #if !os(macOS)
        let isCellular = flags.contains(.isWWAN)
        #endif

        if !connectionRequired && isReachable {
            #if !os(macOS)
            if isCellular {
                self = .online(.cellular)
            } else {
                self = .online(.wifi)
            }
            #else
            self = .online(.wifi)
            #endif
            
        } else {
            self =  .offline
        }
    }
}

internal func connectionStatus() -> ConnectionStatus {
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

    return ConnectionStatus(reachabilityFlags: flags)
}

#endif
