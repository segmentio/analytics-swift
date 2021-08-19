//
//  Logger.swift
//  Segment
//
//  Created by Cody Garvin on 12/14/20.
//

import Foundation

// MARK: - Logging Types

/// The foundation for building out a special logger. If logs need to be directed to a certain area, this is the
/// interface to start off with. For instance a console logger, a networking logger or offline storage logger
/// would all start off with LogTarget.
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

/// Used for analytics.log() types. This lets the system know what to filter on and how to set priorities.
public enum LogFilterKind: Int {
    case error = 0  // Not Verbose (fail cases | non-recoverable errors)
    case warning    // Semi-verbose (deprecations | potential issues)
    case debug      // Verbose (everything of interest)
}

/// The Segment logging system has three types of logs: log, metric and history. When adding a target that
/// responds to logs, it is possible to adhere to 1 to many. In other words, a LoggingType can be .log &
/// .history. This is used to tell which targets logs are directed to.
public struct LoggingType: Hashable {
    
    public enum LogDestination {
        case log
        case metric
        case history
    }
    
    /// Convenience .log logging type
    static let log = LoggingType(types: [.log])
    /// Convenience .metric logging type
    static let metric = LoggingType(types: [.metric])
    /// Convenience .history logging type
    static let history = LoggingType(types: [.history])
    
    
    /// Designated initializer for LoggingType. Add all the destinations this LoggingType should support.
    /// - Parameter types: The LoggingDestination(s) that this LoggingType will support.
    public init(types: [LogDestination]) {
        // TODO: Failable scenario if types empty
        self.allTypes = types
    }
    
    // - Private Properties and Methods
    private let allTypes: [LogDestination]
    
    /// Convience method to find if the LoggingType supports a particular destination.
    /// - Parameter destination: The particular destination being tested for conformance.
    /// - Returns: If the destination exists in this LoggingType `true` or `false` will be returned.
    fileprivate func contains(_ destination: LogDestination) -> Bool {
        return allTypes.contains(destination)
    }
}


/// The interface to the message being returned to `LogTarget` -> `parseLog()`.
public protocol LogMessage {
    var kind: LogFilterKind { get }
    var message: String { get }
    var event: RawEvent? { get }
    var function: String? { get }
    var line: Int? { get }
}


// MARK: - Public Logging API

extension Analytics {
    
    /// The public logging method for capturing all general types of log messages related to Segment.
    /// - Parameters:
    ///   - message: The main message of the log to be captured.
    ///   - kind: Usually .error, .warning or .debug, in order of serverity. This helps filter logs based on
    ///   this added metadata.
    ///   - function: The name of the function the log came from. This will be captured automatically.
    ///   - line: The line number in the function the log came from. This will be captured automatically.
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
    
    /// The public logging method for capturing metrics related to Segment or other libraries.
    /// - Parameters:
    ///   - type: Metric type, usually .counter or .gauge. Select the one that makes sense for the metric.
    ///   - name: The title of the metric to track.
    ///   - value: The value associated with the metric. This would be an incrementing counter or time
    ///   or pressure gauge.
    ///   - tags: Any tags that should be associated with the metric. Any extra metadata that may help.
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
    
    /// Used to track the history of events as the event data travels through the Segment Event Timeline. As
    /// plugins manipulate the data at the `before`, `enrichment`, `destination`,
    /// `destination timeline`, and `after` states, an event can be tracked. Starting with the first one
    /// - Parameters:
    ///   - event: The timeline event that is to be processed.
    ///   - sender: Where the event came from.
    ///   - function: The name of the function the log came from. This will be captured automatically.
    ///   - line: The line number in the function the log came from. This will be captured automatically.
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

// MARK: - Plugin Implementation

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

// MARK: - Internal Types

fileprivate struct LogFactory {
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
//            default:
//                throw NSError(domain: "Could not parse log", code: 2001, userInfo: nil)
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

public extension LogTarget {
    // Make flush optional with an empty implementation.
    func flush() { }
}
