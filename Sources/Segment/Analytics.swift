//
//  Analytics.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation
import Sovran

protocol EdgeFunctionMiddleware {
    // This is a stub
}

// MARK: - Base Setup

public class Analytics {
    internal var configuration: Configuration
    internal let timeline = Timeline()
    
    init(writeKey: String) {
        configuration = Configuration(writeKey: writeKey)
    }
    
    internal init(config: Configuration) {
        configuration = config
    }
    
    func build() -> Analytics {
        timeline.store.provide(state: System(enabled: !configuration.startDisabled))
        return Analytics(config: configuration)
    }
}

// MARK: System Modifiers

extension Analytics {
    
    var enabled: Bool {
        get {
            var result = !configuration.startDisabled
            if let system: System = timeline.store.currentState() {
                result = system.enabled
            }
            return result
        }
        set(value) {
            timeline.store.dispatch(action: System.EnabledAction(enabled: value))
        }
    }
    
    func flush() {
        // ...
    }
    
    func reset() {
        timeline.store.dispatch(action: UserInfo.ResetAction())
    }
    
    func version() -> Int {
        // ...
        return 0
    }
    
    func anonymousId() -> String {
        // ??? not getAnonymousId
        return ""
    }
    
    func deviceToken() -> String {
        // ??? not getDeviceToken
        return ""
    }
    
    func edgeFunction() -> EdgeFunctionMiddleware? {
        return nil
    }
}

// MARK: - Deprecations from previous lib

extension Analytics {
    // NOTE: these have been replaced by a property
    @available(*, deprecated)
    func enable() {
        
    }
    
    @available(*, deprecated)
    func disable() {
        
    }
}
