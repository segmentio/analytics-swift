//
//  UserAgent.swift
//
//
//  Created by Brandon Sneed on 5/6/24.
//

import Foundation

#if os(iOS) || os(visionOS)
import UIKit
#endif

// macOS:     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"
// iOS:       "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
// iPad:      "Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
// visionOS:  "Mozilla/5.0 (iPad; CPU OS 16_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
// catalyst:  "Mozilla/5.0 (iPad; CPU OS 14_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
// appleTV:   no-webkit
// watchOS:   no-webkit
// linux:     no-webkit

internal struct UserAgent {
    // Duplicate the app names that webkit uses on a given platform.
    // Broken out in case they change in the future.
    #if os(macOS)
    private static let defaultWebKitAppName = ""
    #elseif targetEnvironment(macCatalyst)
    private static let defaultWebKitAppName = "Mobile/15E148"
    #elseif os(iOS)
    private static let defaultWebKitAppName = "Mobile/15E148"
    #elseif os(visionOS)
    private static let defaultWebKitAppName = "Mobile/15E148"
    #else
    private static let defaultWebKitAppName = ""
    #endif
    
    @Atomic internal static var _value: String = ""
    internal static let lock = NSLock()
    
    public static var value: String {
        lock.lock()
        defer { lock.unlock() }
        
        if _value.isEmpty {
            __value.set(value(applicationName: defaultWebKitAppName))
        }
        return _value
        //return "someUserAgent"
    }
    
    private static func version() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        var result: String
        if v.patchVersion > 0 {
            result = "\(v.majorVersion)_\(v.minorVersion)_\(v.patchVersion)"
        } else {
            // webkit leaves the patch version off if it's zero.
            result = "\(v.majorVersion)_\(v.minorVersion)"
        }
        return result
    }
    
    public static func value(applicationName: String) -> String {
        let separator: String = applicationName.isEmpty ? "" : " "
        #if os(macOS)
        // Webkit hard-codes the info if it's on mac desktop
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)\(separator)\(applicationName)"
        #elseif os(iOS) || os(visionOS) || targetEnvironment(macCatalyst)
        var model = UIDevice.current.model
        
        // doing this just in case ... i don't have all these devices to test, only sims.
        if model.contains("iPhone") { model = "iPhone" }
        else if model.contains("iPad") { model = "iPad" }
        // it's not one of the two above .. webkit defaults to iPad (ie: visionOS, catalyst), so use that instead of whatever we got.
        else { model = "iPad" }
        
        let osVersion = Self.version()
        #if os(iOS)
        // ios likes to tell you it's an iphone twice.
        return "Mozilla/5.0 (\(model); CPU \(model) OS \(osVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)\(separator)\(applicationName)"
        #else
        return "Mozilla/5.0 (\(model); CPU OS \(osVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)\(separator)\(applicationName)"
        #endif
        
        #else
        return "unknown"
        #endif
    }
}

