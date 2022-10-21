//
//  SegmentLog.swift
//  Segment
//
//  Created by Cody Garvin on 12/14/20.
//

import Foundation

// MARK: - Plugin Implementation

internal class SegmentLog: UtilityPlugin {
    public var filterKind = LogFilterKind.debug
    weak var analytics: Analytics?
    
    let type = PluginType.utility
    
    fileprivate var loggingMediator = [LoggingType: LogTarget]()
    
    // Default to no, enable to see local logs
    internal static var loggingEnabled = false
    
    // For internal use only. Note: This will contain the last created instance
    // of analytics when used in a multi-analytics environment.
    internal static weak var sharedAnalytics: Analytics? = nil
    
    #if DEBUG
    internal static var globalLogger: SegmentLog {
        get {
            let logger = SegmentLog()
            logger.addTargets()
            return logger
        }
    }
    #endif
    
    required init() { }
    
    func configure(analytics: Analytics) {
        self.analytics = analytics
        SegmentLog.sharedAnalytics = analytics
        addTargets()
    }
    
    internal func addTargets() {
        #if !os(Linux)
        try? add(target: SystemTarget(), for: LoggingType.log)
        #if DEBUG
        try? add(target: ConsoleTarget(), for: LoggingType.log)
        #endif
        #else
        try? add(target: ConsoleTarget(), for: LoggingType.log)
        #endif
    }
    
    func update(settings: Settings) {
        // Check for the server-side flag
        if let settingsDictionary = settings.plan?.dictionaryValue,
           let enabled = settingsDictionary["logging_enabled"] as? Bool {
            SegmentLog.loggingEnabled = enabled
        }
    }
    
    internal func log(_ logMessage: LogMessage, destination: LoggingType.LogDestination) {
        
        for (logType, target) in loggingMediator {
            if logType.contains(destination) {
                target.parseLog(logMessage)
            }
        }
    }
    
    internal func add(target: LogTarget, for loggingType: LoggingType) throws {
        
        // Verify the target does not exist, if it does bail out
        let filtered = loggingMediator.filter { (type: LoggingType, existingTarget: LogTarget) in
            Swift.type(of: existingTarget) == Swift.type(of: target)
        }
        if filtered.isEmpty == false { throw NSError(domain: "Target already exists", code: 2002, userInfo: nil) }
        
        // Finally add the target
        loggingMediator[loggingType] = target
    }
    
    internal func flush() {
        for (_, target) in loggingMediator {
            target.flush()
        }
        
        // TODO: Clean up history container here
    }
}

// MARK: - Internal Types

internal struct LogFactory {
    static func buildLog(destination: LoggingType.LogDestination,
                         title: String,
                         message: String,
                         kind: LogFilterKind = .debug,
                         function: String? = nil,
                         line: Int? = nil,
                         event: RawEvent? = nil,
                         sender: Any? = nil,
                         value: Double? = nil,
                         tags: [String]? = nil) -> LogMessage {
        
        switch destination {
            case .log:
                return GenericLog(kind: kind, message: message, function: function, line: line)
            case .metric:
                return MetricLog(title: title, message: message, value: value ?? 1, event: event, function: function, line: line)
            case .history:
                return HistoryLog(message: message, event: event, function: function, line: line, sender: sender)
        }
    }
    
    fileprivate struct GenericLog: LogMessage {
        var kind: LogFilterKind
        var title: String?
        var message: String
        var event: RawEvent? = nil
        var function: String?
        var line: Int?
        var logType: LoggingType.LogDestination = .log
        var dateTime = Date()
    }
    
    fileprivate struct MetricLog: LogMessage {
        var title: String?
        var kind: LogFilterKind = .debug
        var message: String
        var value: Double
        var event: RawEvent?
        var function: String? = nil
        var line: Int? = nil
        var logType: LoggingType.LogDestination = .metric
        var dateTime = Date()
    }
    
    fileprivate struct HistoryLog: LogMessage {
        var kind: LogFilterKind = .debug
        var title: String?
        var message: String
        var event: RawEvent?
        var function: String?
        var line: Int?
        var sender: Any?
        var logType: LoggingType.LogDestination = .history
        var dateTime = Date()
    }
}

public extension LogTarget {
    // Make flush optional with an empty implementation.
    func flush() { }
}

internal extension Analytics {
    /// The internal logging method for capturing all general types of log messages related to Segment.
    /// - Parameters:
    ///   - message: The main message of the log to be captured.
    ///   - kind: Usually .error, .warning or .debug, in order of serverity. This helps filter logs based on
    ///   this added metadata.
    ///   - function: The name of the function the log came from. This will be captured automatically.
    ///   - line: The line number in the function the log came from. This will be captured automatically.
    static func segmentLog(message: String, kind: LogFilterKind? = nil, function: String = #function, line: Int = #line) {
        if let shared = SegmentLog.sharedAnalytics {
            shared.apply { plugin in
                if let loggerPlugin = plugin as? SegmentLog {
                    var filterKind = loggerPlugin.filterKind
                    if let logKind = kind {
                        filterKind = logKind
                    }
                    
                    let log = LogFactory.buildLog(destination: .log, title: "", message: message, kind: filterKind, function: function, line: line)
                    loggerPlugin.log(log, destination: .log)
                }
            }
        } else {
            #if DEBUG
            let log = LogFactory.buildLog(destination: .log, title: "", message: message, kind: .debug, function: function, line: line)
            SegmentLog.globalLogger.log(log, destination: .log)
            #endif
        }
    }
    
    /// The internal logging method for capturing metrics related to Segment or other libraries.
    /// - Parameters:
    ///   - type: Metric type, usually .counter or .gauge. Select the one that makes sense for the metric.
    ///   - name: The title of the metric to track.
    ///   - value: The value associated with the metric. This would be an incrementing counter or time
    ///   or pressure gauge. Defaults to 1 if not specified.
    ///   - tags: Any tags that should be associated with the metric. Any extra metadata that may help.
    static func segmentMetric(_ type: MetricType, name: String, value: Double, tags: [String]? = nil) {
        SegmentLog.sharedAnalytics?.apply { plugin in
            
            if let loggerPlugin = plugin as? SegmentLog {
                let log = LogFactory.buildLog(destination: .metric, title: type.toString(), message: name, value: value, tags: tags)
                loggerPlugin.log(log, destination: .metric)
            }
        }
    }
}
