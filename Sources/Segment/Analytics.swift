//
//  Analytics.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation
import Sovran

// MARK: - Base Setup

public class Analytics {
    internal var configuration: Configuration
    internal var store: Store
    internal var storage: Storage

    private var built = false

    /// Enabled/disables debug logging to trace your data going through the SDK.
    public var debugLogsEnabled = false
    
    public var timeline: Timeline
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        
        store = Store()
        storage = Storage(store: self.store, writeKey: configuration.writeKey)
        timeline = Timeline()
        
        // provide our default state
        store.provide(state: System.defaultState(configuration: configuration, from: storage))
        store.provide(state: UserInfo.defaultState(from: storage))
        
        // Get everything hot and sweaty here
        platformStartup()
    }
    
    internal func process<E: RawEvent>(incomingEvent: E) {
        let event = incomingEvent.applyRawEventData(store: store)
        _ = timeline.process(incomingEvent: event)
    }
}

// MARK: - System Modifiers

extension Analytics {
    public var enabled: Bool {
        get {
            var result = !configuration.values.startDisabled
            if let system: System = store.currentState() {
                result = system.enabled
            }
            return result
        }
        set(value) {
            store.dispatch(action: System.EnabledAction(enabled: value))
        }
    }
    
    public func flush() {
        flushCurrentPayload()
    }
    
    public func reset() {
        store.dispatch(action: UserInfo.ResetAction())
    }
    
    public func anonymousId() -> String {
        // ??? not getAnonymousId
        return ""
    }
    
    public func deviceToken() -> String {
        // ??? not getDeviceToken
        return ""
    }
    
    public func edgeFunction() -> Any? {
        return nil
    }
    
    public func settings() -> Settings? {
        var settings: Settings?
        if let system: System = store.currentState() {
            settings = system.settings
        }
        return settings
    }
    
    public func version() -> String {
        return Analytics.version()
    }
    
    public static func version() -> String {
        return __segment_version
    }
}
