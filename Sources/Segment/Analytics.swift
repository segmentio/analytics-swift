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
    internal var timeline: Timeline

    private var built = false

    /// Enabled/disables debug logging to trace your data going through the SDK.
    public var debugLogsEnabled = false
    
    public let extensions: Extensions
    
    init(writeKey: String) {
        self.configuration = Configuration(writeKey: writeKey)
        self.store = Store()
        self.timeline = Timeline()
        self.extensions = Extensions(timeline: timeline)
    }
    
    func build() -> Analytics {
        if (built) {
            assertionFailure("Analytics.build() can only be called once!")
        }
        built = true
        
        timeline.analytics = self
        
        // provide our default state
        store.provide(state: System(enabled: !configuration.startDisabled, configuration: configuration, context: nil, integrations: nil))
        store.provide(state: UserInfo(anonymousId: UUID().uuidString, userId: nil, traits: nil))

        return self
    }
}

// MARK: System Modifiers

extension Analytics {
    public var enabled: Bool {
        get {
            var result = !configuration.startDisabled
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
        // ...
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
    
    public func version() -> String {
        return Analytics.version()
    }
    
    public static func version() -> String {
        return __segment_version
    }
}
