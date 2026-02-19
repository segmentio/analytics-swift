//
//  EventDebugger.swift
//  Segment
//
//  Created by Brandon Sneed on 11/1/25.
//

import Foundation
import OSLog

public class EventDebugger: EventPlugin {
    public var type: PluginType = .after
    public weak var analytics: Analytics? = nil
    
    /// If true, prints full event JSON. If false, prints compact summary.
    public var verbose: Bool = false
    
    private let logger: OSLog
    
    required public init() {
        self.logger = OSLog(subsystem: "com.segment.analytics", category: "events")
    }
    
    public func identify(event: IdentifyEvent) -> IdentifyEvent? {
        log(event: event, dot: "🟣", type: "Analytics.IDENTIFY")
        return event
    }
    
    public func track(event: TrackEvent) -> TrackEvent? {
        log(event: event, dot: "🔵", type: "Analytics.TRACK")
        return event
    }
    
    public func group(event: GroupEvent) -> GroupEvent? {
        log(event: event, dot: "🟡", type: "Analytics.GROUP")
        return event
    }
    
    public func alias(event: AliasEvent) -> AliasEvent? {
        log(event: event, dot: "🟢", type: "Analytics.ALIAS")
        return event
    }
    
    public func screen(event: ScreenEvent) -> ScreenEvent? {
        log(event: event, dot: "🟠", type: "Analytics.SCREEN")
        return event
    }
    
    public func reset() {
        os_log("🔴 [Analytics.RESET]", log: logger, type: .info)
    }
    
    public func flush() {
        os_log("⚪ [Analytics.FLUSH]", log: logger, type: .info)
    }
    
    // MARK: - Private Helpers
    
    private func log(event: RawEvent, dot: String, type: String) {
        if verbose {
            logVerbose(event: event, dot: dot, type: type)
        } else {
            logCompact(event: event, dot: dot, type: type)
        }
    }
    
    private func logCompact(event: RawEvent, dot: String, type: String) {
        var summary = "\(dot) [\(type)]"
        
        // Add event-specific details
        if let track = event as? TrackEvent {
            summary += " \(track.event)"
        } else if let screen = event as? ScreenEvent {
            summary += " \(screen.name ?? screen.category ?? "Screen")"
        } else if let identify = event as? IdentifyEvent {
            summary += " userId: \(identify.userId ?? "nil")"
        } else if let group = event as? GroupEvent {
            summary += " groupId: \(group.groupId ?? "nil")"
        } else if let alias = event as? AliasEvent {
            summary += " \(alias.previousId ?? "nil") → \(alias.userId ?? "nil")"
        }
        
        os_log("%{public}@", log: logger, type: .debug, summary)
    }
    
    private func logVerbose(event: RawEvent, dot: String, type: String) {
        // Pretty-print the JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(event),
           let jsonString = String(data: data, encoding: .utf8) {
            os_log("%{public}@ [%{public}@]\n%{public}@",
                   log: logger,
                   type: .debug,
                   dot,
                   type,
                   jsonString)
        } else {
            os_log("%{public}@ [%{public}@] Failed to encode event",
                   log: logger,
                   type: .error,
                   dot,
                   type)
        }
    }
}
