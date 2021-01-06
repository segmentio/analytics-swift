//
//  Startup.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

extension Analytics {
        
    internal func platformStartup() {
        
        // add segment destination extension
        // ...
        
        // Setup platform specific extensions
        if let platformExtensions = platformExtensions() {
            for extensionType in platformExtensions {
                let prebuilt = extensionType.init(name: extensionType.specificName)
                prebuilt.analytics = self
                extensions.add(prebuilt)
            }
        }
        
        // other setup/config stuff.
        // ...
        
        setupSettingsCheck()
    }
    
    internal func platformExtensions() -> [PlatformExtension.Type]? {
        var extensions = [PlatformExtension.Type]()
        
        // setup lifecycle if desired
        if configuration.trackApplicationLifecycleEvents {
            #if os(iOS) || os(watchOS) || os(tvOS)
            extensions.append(iOSLifecycleEvents.self)
            #endif
            #if os(macOS)
            extensions.append(macOSLifecycleEvents.self)
            #endif
            #if os(Linux)
            extensions.append(LinuxLifecycleEvents.self)
            #endif
        }
        
        if extensions.isEmpty {
            return nil
        } else {
            return extensions
        }
    }
}

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
extension Analytics {
    internal func setupSettingsCheck() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main) { (notification) in
            self.checkSettings()
        }
    }
}
#elseif os(macOS)
import Cocoa
extension Analytics {
    internal func setupSettingsCheck() {
        NotificationCenter.default.addObserver(forName: NSApplication.willBecomeActiveNotification, object: nil, queue: OperationQueue.main) { (notification) in
            self.checkSettings()
        }
    }
}
#elseif os(Linux)
extension Analytics {
    internal func setupSettingsCheck() {
        // TBD: we don't know what to do here.
    }
}
#endif
