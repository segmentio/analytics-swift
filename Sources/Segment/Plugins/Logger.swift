//
//  Logger.swift
//  Segment
//
//  Created by Cody Garvin on 12/14/20.
//

import Foundation

internal class Logger: UtilityPlugin {
    public var filterKind = LogFilterKind.debug
    
    let type = PluginType.utility
    var analytics: Analytics?
    
    fileprivate var loggingMediator = [LoggingType: LogTarget]()
    
    required init() { }
    
    internal func log(_ logMessage: LogMessage, destination: LoggingType.LogDestination) {
        
        for (logType, target) in loggingMediator {
            if logType.contains(destination) {
                target.parseLog(logMessage)
            }
        }
    }
    
    func flush() {
        for (_, target) in loggingMediator {
            target.flush()
        }
    }

}

// MARK: - Types
public protocol LogTarget {
    
    /// Implement this method to process logging messages. This is where the logic for the target will be
    /// added. Feel free to add your own data queueing and offline storage.
    /// - important: Use the Segment Network stack for Segment library compatibility and simplicity.
    func parseLog(_ log: LogMessage)
    
    /// Optional method to implement. This helps respond to potential queueing events being flushed out.
    /// Perhaps responding to backgrounding or networking events, this gives a chance to empty a queue
    /// or pump a firehose of logs.
    func flush()
}

extension LogTarget {
    // Make flush optional with an empty implementation.
    func flush() { }
}

public enum LogFilterKind: Int {
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

public protocol LogMessage {
    var kind: LogFilterKind { get }
    var message: String { get }
    var event: RawEvent? { get }
    var function: String? { get }
    var line: Int? { get }
}


// MARK: - Public Logging API
extension Analytics {
    
    public func log(message: String, kind: LogFilterKind? = nil, function: String = #function, line: Int = #line) {
        apply { plugin in
            if let loggerPlugin = plugin as? Logger {
                var filterKind = loggerPlugin.filterKind
                if let logKind = kind {
                    filterKind = logKind
                }
                do {
                    let log = try LogFactory.buildLog(destination: .log, title: "", message: message, kind: filterKind, function: function, line: line)
                    loggerPlugin.log(log, destination: .log)
                } catch {
                    // TODO: LOG TO PRIVATE SEGMENT LOG
                }
            }
        }
    }
    
    public func metric(_ type: String, name: String, value: Double, tags: [String]? = nil) {
        apply { plugin in
            if let loggerPlugin = plugin as? Logger {
                do {
                    let log = try LogFactory.buildLog(destination: .metric, title: type, message: name, value: value, tags: tags)
                    loggerPlugin.log(log, destination: .metric)
                } catch {
                    // TODO: LOG TO PRIVATE SEGMENT LOG
                }
            }
        }
    }
    
    public func history(event: RawEvent, sender: AnyObject, function: String = #function, line: Int = #line) {
        apply { plugin in
            if let loggerPlugin = plugin as? Logger {
                do {
                    let log = try LogFactory.buildLog(destination: .history, title: event.toString(), message: "", function: function, line: line, event: event, sender: sender)
                    loggerPlugin.log(log, destination: .metric)
                } catch {
                    // TODO: LOG TO PRIVATE SEGMENT LOG
                }
            }
        }
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

struct LogFactory {
    static func buildLog(destination: LoggingType.LogDestination,
                         title: String,
                         message: String,
                         kind: LogFilterKind = .debug,
                         function: String? = nil,
                         line: Int? = nil,
                         event: RawEvent? = nil,
                         sender: Any? = nil,
                         value: Double? = nil,
                         tags: [String]? = nil) throws -> LogMessage {
        
        switch destination {
            case .log:
                return GenericLog(kind: kind, message: message, function: function, line: line)
            case .metric:
                return MetricLog(title: title, message: message, event: event, function: function, line: line)
            case .history:
                return HistoryLog(message: message, event: event, function: function, line: line, sender: sender)
            default:
                throw NSError(domain: "Could not parse log", code: 2001, userInfo: nil)
        }
    }
    
    fileprivate struct GenericLog: LogMessage {
        var kind: LogFilterKind
        var message: String
        var event: RawEvent? = nil
        var function: String?
        var line: Int?
    }
    
    fileprivate struct MetricLog: LogMessage {
        var title: String
        var kind: LogFilterKind = .debug
        var message: String
        var event: RawEvent?
        var function: String? = nil
        var line: Int? = nil
    }
    
    fileprivate struct HistoryLog: LogMessage {
        var kind: LogFilterKind = .debug
        var message: String
        var event: RawEvent?
        var function: String?
        var line: Int?
        var sender: Any?
    }
}
