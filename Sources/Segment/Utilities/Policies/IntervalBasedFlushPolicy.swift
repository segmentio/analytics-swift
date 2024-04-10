//
//  IntervalBasedFlushPolicy.swift
//  
//
//  Created by Alan Charles on 4/11/23.
//

import Foundation
import Sovran


public class IntervalBasedFlushPolicy: FlushPolicy,
                                       Subscriber {
    public weak var analytics: Analytics?
    internal var desiredInterval: TimeInterval?
    internal var flushTimer: QueueTimer? = nil
    
    public init() { }
    
    public init(interval: TimeInterval) {
        desiredInterval = interval
    }
    
    deinit {
        flushTimer?.suspend()
        flushTimer = nil
    }
    
    // all we need to do is check for a custom `flushInterval` if it exists we set `config.flushInterval` otherwise we set the QueueTimer to use the `flushInterval` from the config
    
    public func configure(analytics: Analytics) {
        self.analytics = analytics
        
        if let desiredInterval = desiredInterval {
            analytics.flushInterval = desiredInterval
        }
        
        // `flushInterval` can change post-initialization so we subscribe to changes here
        self.analytics?.store.subscribe(self, initialState: true) { [weak self] (state: System) in
            guard let self = self else { return }
            guard let a = self.analytics else { return }
            guard let system: System = a.store.currentState() else { return }
            self.flushTimer = QueueTimer(interval: system.configuration.values.flushInterval) { [weak self] in
                self?.analytics?.flush()
            }
        }
    }
    
    public func shouldFlush() -> Bool {
        // always return false since QueueTimer can handle flush logic
        return false
    }
    
    public func updateState(event: RawEvent) { }
    
    public func reset() { }
    
    // MARK: - Abstracted Lifecycle Methods
    
    internal func enterForeground() {
        flushTimer?.resume()
    }
    
    internal func enterBackground() {
        flushTimer?.suspend()
        self.analytics?.flush()
    }
}
