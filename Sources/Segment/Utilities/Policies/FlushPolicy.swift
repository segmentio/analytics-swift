//
//  FlushPolicy.swift
//  
//
//  Created by Alan Charles on 3/21/23.
//

import Foundation

public protocol FlushPolicy: AnyObject {
    var analytics: Analytics? { get set }
    func configure(analytics: Analytics) -> Void
    func shouldFlush() -> Bool
    func updateState(event: RawEvent) -> Void
    func reset() -> Void
}

public extension Analytics {
    func add(flushPolicy: FlushPolicy) {
        guard let state: System = store.currentState() else { return }
        let config = state.configuration
        var policies = config.values.flushPolicies
        policies.append(flushPolicy)
        config.flushPolicies(policies)
        store.dispatch(action: System.UpdateConfigurationAction(configuration: config))
        
        flushPolicy.configure(analytics: self)
    }
    
    func remove(flushPolicy: FlushPolicy) {
        guard let state: System = store.currentState() else { return }
        let config = state.configuration
        let policies = config.values.flushPolicies.filter { policy in
            return flushPolicy !== policy
        }
        config.flushPolicies(policies)
        store.dispatch(action: System.UpdateConfigurationAction(configuration: config))
    }
    
    func remove<T: FlushPolicy>(flushPolicy: T.Type) {
        guard let state: System = store.currentState() else { return }
        let config = state.configuration
        let policies = config.values.flushPolicies.filter { policy in
            return !(policy is T)
        }
        config.flushPolicies(policies)
        store.dispatch(action: System.UpdateConfigurationAction(configuration: config))
    }
    
    func removeAllFlushPolicies() {
        guard let state: System = store.currentState() else { return }
        let config = state.configuration
        config.flushPolicies([])
        store.dispatch(action: System.UpdateConfigurationAction(configuration: config))
    }
    
    func find<T: FlushPolicy>(flushPolicy: T.Type) -> FlushPolicy? {
        guard let state: System = store.currentState() else { return nil }
        let config = state.configuration
        let found = config.values.flushPolicies.filter { policy in
            return policy is T
        }
        return found.first
    }
}
