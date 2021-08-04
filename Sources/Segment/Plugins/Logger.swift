//
//  Logger.swift
//  Segment
//
//  Created by Cody Garvin on 12/14/20.
//

import Foundation

public enum LogType: Int {
    case error = 0  // Not Verbose
    case warning    // Semi-verbose
    case info       // Verbose
}

class Logger: UtilityPlugin {
    public var filterType = LogType.info
    
    let type = PluginType.utility
    var analytics: Analytics?
    
    private var messages = [LogMessage]()
    
    required init() { }
    
    func log(type: LogType, message: String, event: RawEvent?) {
        print("\(type) -- Message: \(message)")
        let message = LogMessage(type: type, message: message, event: event)
        messages.append(message)
    }
    
    func flush() {
        print("Flushing All Logs")
        for message in messages {
            if message.type.rawValue <= filterType.rawValue {
                print("[\(message.type)] \(message.message)")
            }
        }
        messages.removeAll()
    }
}

fileprivate struct LogMessage {
    let type: LogType
    let message: String
    let event: RawEvent?
}

extension Analytics {
    
    /// Log a generic message to the system with a possible log type. If a type is not supplied the system
    /// will use the current default setting (.info).
    /// - Parameters:
    ///   - message: The message to be stored in the logging system.
    ///   - event: The event associated with the log (optional).
    ///   - type: The filter type for the message. If nil, defaults to logger setting.
    public func log(message: String, event: RawEvent? = nil, type: LogType? = nil) {
        apply { (potentialLogger) in
            
            if let logger = potentialLogger as? Logger {
                
                var loggingType = logger.filterType
                if let type = type {
                    loggingType = type
                }
                logger.log(type: loggingType, message: message, event: event)
            }
        }
    }
    
    public func logFlush() {
        apply { (potentialLogger) in
            if let logger = potentialLogger as? Logger {
                logger.flush()
            }
        }
    }
}
