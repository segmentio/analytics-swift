//
//  Logging.swift
//  
//
//  Created by Brandon Sneed on 3/9/23.
//

import Foundation

extension Analytics {
    internal enum LogKind {
        case error
        case warning
        case debug
        case none
        
        var string: String {
            switch self {
            case .error:
                return "SEG_ERROR: "
            case .warning:
                return "SEG_WARNING: "
            case .debug:
                return "SEG_DEBUG: "
            case .none:
                return ""
            }
        }
    }
    
    public func log(message: String) {
        Self.segmentLog(message: message, kind: .none)
    }
    
    static internal func segmentLog(message: String, kind: LogKind) {
        #if DEBUG
        if Self.debugLogsEnabled {
            print("\(kind)\(message)")
        }
        #endif
    }
}
