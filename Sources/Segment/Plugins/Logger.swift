//
//  Logger.swift
//  Segment
//
//  Created by Cody Garvin on 12/14/20.
//

import Foundation

internal class Logger: UtilityPlugin {
    public var filterKind = LogKind.debug
    
    let type = PluginType.utility
    var analytics: Analytics?
    
    private var messages = [LogMessage]()
    fileprivate var loggingMediator = [LoggingType: LogTarget]()
    
    required init() { }
    
    func log(destination: LoggingType.LogDestination, message: String, logKind: LogKind, function: String, line: Int) {
        let message = LogMessage(kind: logKind, message: message, event: nil, function: function, line: line)
        
        for (logType, target) in loggingMediator {
            if logType.contains(destination) {
                target.parseLog(message)
            }
        }
    }
    
    func flush() {
        print("Flushing All Logs")
        for message in messages {
            if message.kind.rawValue <= filterKind.rawValue {
                print("[\(message.kind)] \(message.message)")
            }
        }
        messages.removeAll()
    }
}

// MARK: - Types
public protocol LogTarget {
        
    func parseLog(_ log: LogMessage)
    func flush()
}

extension LogTarget {
    // Make flush optional with an empty implementation.
    func flush() { }
}

public enum LogKind: Int {
    case error = 0  // Not Verbose (fail cases | non-recoverable errors)
    case warning    // Semi-verbose (deprecations | potential issues)
    case debug      // Verbose (everything of interest)
}

public struct LoggingType: Hashable {
    private let allTypes: [LogDestination]
    
    public enum LogDestination {
        case log
        case metric
        case history
    }
    
    static let log = LoggingType(types: [.log])
    static let metric = LoggingType(types: [.metric])
    static let history = LoggingType(types: [.history])
    
    public init(types: [LogDestination]) {
        self.allTypes = types
    }
    
    public func contains(_ type: LogDestination) -> Bool {
        return allTypes.contains(type)
    }
}

public struct LogMessage {
    let kind: LogKind
    let message: String
    let event: RawEvent?
    let function: String?
    let line: Int?
}


// MARK: - Public Logging API
extension Analytics {
    
    public func log(message: String, kind: LogKind? = nil, function: String = #function, line: Int = #line) {
        apply { plugin in
            if let loggerPlugin = plugin as? Logger {
                var filterKind = loggerPlugin.filterKind
                if let logKind = kind {
                    filterKind = logKind
                }
                loggerPlugin.log(destination: .log, message: message, logKind: filterKind, function: function, line: line)
            }
        }
    }
    
    public func metric(_ type: String, name: String, value: Double, tags: [String]? = nil) {
        apply { plugin in
            if let loggerPlugin = plugin as? Logger {
//                loggerPlugin.log(destination: .metric, message: message, logKind: filterKind, function: function, line: line)
            }
        }
    }
    
    public func history(event: RawEvent, sender: AnyObject, function: String = #function) {
        
    }
}

extension Analytics {
    
    /// Add a logging target to the system. These `targets` can handle logs in various ways. Consider
    /// sending logs to the console, the OS and a web service. Three targets can handle these scenarios.
    /// - Parameters:
    ///   - target: A `LogTarget` that has logic to parse and handle log messages.
    ///   - type: The type consists of `log`, `metric` or `history`. These correspond to the
    ///   public API on Analytics.
    public func add(target: LogTarget, type: LoggingType) {
        apply { (potentialLogger) in
            if let logger = potentialLogger as? Logger {
                logger.loggingMediator[type] = target
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

