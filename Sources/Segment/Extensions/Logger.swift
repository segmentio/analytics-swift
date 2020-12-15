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

class Logger: Extension {
    
    public var filterType: LogType = .info
    
    var type: ExtensionType
    var name: String
    var analytics: Analytics?
    
    private var messages = [LogMessage]()
    
    required init(name: String) {
        self.name = name
        self.type = .none
    }
    
    func execute() {
        // none
    }
    
    func log(type: LogType, message: String) {
        print("\(type) -- Message: \(message)")
        let message = LogMessage(type: type, message: message)
        messages.append(message)
    }
    
    func flush() {
        print("Flushing")
        for message in messages {
            if message.type.rawValue <= filterType.rawValue {
                print(message.message)
            }
        }
        messages.removeAll()
    }
}

fileprivate struct LogMessage {
    let type: LogType
    let message: String
}

extension Analytics {
    
    /// Log a generic message to the system with a possible log type. If a type is not supplied the system
    /// will use the current default setting (.info).
    /// - Parameters:
    ///   - message: The message to be stored in the logging system.
    ///   - type: The filter type for the message
    func log(message: String, type: LogType? = nil) {
        self.extensions.timeline.applyToExtensions { (potentialLogger) in
            if let logger = potentialLogger as? Logger {
                
                var loggingType = logger.filterType
                if let type = type {
                    loggingType = type
                }
                logger.log(type: loggingType, message: message)
            }
        }
    }
}
