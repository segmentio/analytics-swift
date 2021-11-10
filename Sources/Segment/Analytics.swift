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
    
    /// Enabled/disables debug logging to trace your data going through the SDK.
    public static var debugLogsEnabled = false {
        didSet {
            SegmentLog.loggingEnabled = debugLogsEnabled
        }
    }
    
    public var timeline: Timeline
    
    /// Initialize this instance of Analytics with a given configuration setup.
    /// - Parameters:
    ///    - configuration: The configuration to use
    public init(configuration: Configuration) {
        self.configuration = configuration
        
        store = Store()
        storage = Storage(store: self.store, writeKey: configuration.values.writeKey)
        timeline = Timeline()
        
        // provide our default state
        store.provide(state: System.defaultState(configuration: configuration, from: storage))
        store.provide(state: UserInfo.defaultState(from: storage))
        
        // Get everything running
        platformStartup()
    }
    
    internal func process<E: RawEvent>(incomingEvent: E) {
        let event = incomingEvent.applyRawEventData(store: store)
        _ = timeline.process(incomingEvent: event)
    }
    
    /// Process a raw event through the system.  Useful when one needs to queue and replay events at a later time.
    /// - Parameters:
    ///   - event: An event conforming to RawEvent that will be processed.
    public func process(event: RawEvent) {
        switch event {
        case let e as TrackEvent:
            timeline.process(incomingEvent: e)
        case let e as IdentifyEvent:
            timeline.process(incomingEvent: e)
        case let e as ScreenEvent:
            timeline.process(incomingEvent: e)
        case let e as GroupEvent:
            timeline.process(incomingEvent: e)
        case let e as AliasEvent:
            timeline.process(incomingEvent: e)
        default:
            break
        }
    }
}

// MARK: - System Modifiers

extension Analytics {
    /// Returns the anonymousId currently in use.
    public var anonymousId: String {
        if let userInfo: UserInfo = store.currentState() {
            return userInfo.anonymousId
        }
        return ""
    }
    
    /// Returns the userId that was specified in the last identify call.
    public var userId: String? {
        if let userInfo: UserInfo = store.currentState() {
            return userInfo.userId
        }
        return nil
    }
    
    /// Returns the traits that were specified in the last identify call.
    public func traits<T: Codable>() -> T? {
        if let userInfo: UserInfo = store.currentState() {
            return userInfo.traits?.codableValue()
        }
        return nil
    }
    
    /// Tells this instance of Analytics to flush any queued events up to Segment.com.  This command will also
    /// be sent to each plugin present in the system.
    public func flush() {
        apply { plugin in
            if let p = plugin as? EventPlugin {
                p.flush()
            }
        }
    }
    
    /// Resets this instance of Analytics to a clean slate.  Traits, UserID's, anonymousId, etc are all cleared or reset.  This
    /// command will also be sent to each plugin present in the system.
    public func reset() {
        store.dispatch(action: UserInfo.ResetAction())
        apply { plugin in
            if let p = plugin as? EventPlugin {
                p.reset()
            }
        }
    }
    
    /// Retrieve the version of this library in use.
    /// - Returns: A string representing the version in "BREAKING.FEATURE.FIX" format.
    public func version() -> String {
        return Analytics.version()
    }
    
    /// Retrieve the version of this library in use.
    /// - Returns: A string representing the version in "BREAKING.FEATURE.FIX" format.
    public static func version() -> String {
        return __segment_version
    }
}

extension Analytics {
    /// Manually retrieve the settings that were supplied from Segment.com.
    /// - Returns: A Settings object containing integration settings, tracking plan, etc.
    public func settings() -> Settings? {
        var settings: Settings?
        if let system: System = store.currentState() {
            settings = system.settings
        }
        return settings
    }
    
    /// Manually enable a destination plugin.  This is useful when a given DestinationPlugin doesn't have any Segment tie-ins at all.
    /// This will allow the destination to be processed in the same way within this library.
    /// - Parameters:
    ///   - plugin: The destination plugin to enable.
    public func manuallyEnableDestination(plugin: DestinationPlugin) {
        self.store.dispatch(action: System.AddDestinationToSettingsAction(key: plugin.key))
    }

}
