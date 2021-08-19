//
//  LinuxUtils.swift
//  Segment
//
//  Created by Brandon Sneed on 2/24/21.
//

import Foundation

#if os(Linux)

class LinuxVendorSystem: VendorSystem {
    override var manufacturer: String {
        return "unknown"
    }
    
    override var type: String {
        return "Linux"
    }
    
    override var model: String {
        return "unknown"
    }
    
    override var name: String {
        return "unknown"
    }
    
    override var identifierForVendor: String? {
        return nil
    }
    
    override var systemName: String {
        return "unknown"
    }
    
    override var systemVersion: String {
        return ""
    }
    
    override var screenSize: ScreenSize {
        return ScreenSize(width: 0, height: 0)
    }
    
    override var userAgent: String? {
        return "unknown"
    }
    
    override var connection: ConnectionStatus {
        return ConnectionStatus.unknown
    }
    
    override var requiredPlugins: [PlatformPlugin] {
        return []
    }
}

#endif
