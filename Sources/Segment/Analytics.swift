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
    
    public var plugins: Plugins
    
    public init(writeKey: String) {
        self.configuration = Configuration(writeKey: writeKey)
        self.store = Store()
        self.storage = Storage(store: self.store, writeKey: writeKey)
        self.plugins = Plugins()
    }
    
    public func build() -> Analytics {
        if (built) {
            assertionFailure("Analytics.build() can only be called once!")
        }
        
        built = true
        
        // provide our default state
        store.provide(state: System.defaultState(configuration: configuration, from: storage))
        store.provide(state: UserInfo.defaultState(from: storage))
        
        // Get everything hot and sweaty here
        platformStartup()

        // finally, kick off settings fetch
        setupSettingsCheck()
        
        return self
    }
    
    internal func process<E: RawEvent>(incomingEvent: E) {
        _ = plugins.timeline.process(incomingEvent: incomingEvent)
    }
}

// MARK: - System Modifiers

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
        let currentBundle = Bundle(for: Analytics.self)
        if let appVersion = currentBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return appVersion
        } else {
            return __segment_version
        }
    }
}
