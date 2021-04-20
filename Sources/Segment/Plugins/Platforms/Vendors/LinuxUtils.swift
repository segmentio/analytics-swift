//
//  LinuxUtils.swift
//  Segment
//
//  Created by Brandon Sneed on 2/24/21.
//

import Foundation

#if os(Linux)

class LinuxVendorSystem: VendorSystem {
    var manufacturer: String {
        return "unknown"
    }
    
    var type: String {
        return "Linux"
    }
    
    var model: String {
        return "unknown"
    }
    
    var name: String {
        return "unknown"
    }
    
    var identifierForVendor: String? {
        return nil
    }
    
    var systemName: String {
        return "unknown"
    }
    
    var systemVersion: String {
        return ""
    }
    
    var screenSize: ScreenSize {
        return ScreenSize(width: 0, height: 0)
    }
    
    var userAgent: String? {
        return "unknown"
    }
    
    var connection: ConnectionStatus {
        return ConnectionStatus.unknown
    }

}

#endif
