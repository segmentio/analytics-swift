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

    private var built = false

    /// Enabled/disables debug logging to trace your data going through the SDK.
    public var debugLogsEnabled = false
    
    private var _extensions: Extensions!
    public var extensions: Extensions {
        return _extensions
    }
    
    init(writeKey: String) {
        self.configuration = Configuration(writeKey: writeKey)
        self.store = Store()
        self._extensions = Extensions(analytics: self)
    }
    
    func build() -> Analytics {
        if (built) {
            assertionFailure("Analytics.build() can only be called once!")
        }
//        extensions.analytics = self
        built = true
        
        // provide our default state
        store.provide(state: System(enabled: !configuration.startDisabled, configuration: configuration, context: nil, integrations: nil))
        store.provide(state: UserInfo(anonymousId: UUID().uuidString, userId: nil, traits: nil))

        return self
    }
    
    internal func process<E: RawEvent>(incomingEvent: E) {
        _ = extensions.timeline.process(incomingEvent: incomingEvent)
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
        let currentBundle = Bundle(for: Analytics.self)
        if let appVersion = currentBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return appVersion
        } else {
            return __segment_version
        }
    }
}
