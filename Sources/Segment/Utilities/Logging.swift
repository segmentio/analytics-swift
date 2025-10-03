//
//  Logging.swift
//  
//
//  Created by Brandon Sneed on 3/9/23.
//

import Foundation

extension Analytics {
    public enum LogKind: CustomStringConvertible, CustomDebugStringConvertible {
        case error
        case warning
        case debug
        case none
        
        public var description: String { return string }
        public var debugDescription: String { return string }

        var string: String {
            switch self {
            case .error:
                return "SEG_ERROR: "
            case .warning:
                return "SEG_WARNING: "
            case .debug:
                return "SEG_DEBUG: "
            case .none:
                return "SEG_INFO: "
            }
        }
    }
    
    public func log(message: String) {
        Self.segmentLog(message: message, kind: .none)
    }
    
    static public func segmentLog(message: String, kind: LogKind) {
        #if DEBUG
        if Self.debugLogsEnabled {
            print("\(kind)\(message)")
        }
        #endif
    }
}
