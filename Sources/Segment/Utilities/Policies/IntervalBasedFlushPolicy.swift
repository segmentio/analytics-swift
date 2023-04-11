//
//  IntervalBasedFlushPolicy.swift
//  
//
//  Created by Alan Charles on 4/11/23.
//

import Foundation


public class IntervalBasedFlushPolicy: FlushPolicy {
    public var analytics: Analytics?
    internal var desiredInterval: TimeInterval?
    internal var flushTimer: QueueTimer? = nil
    
    init() { }
    
    init(interval: TimeInterval) {
        desiredInterval = interval
    }
    
    // all we need to do is check for a custom `flushInterval` if it exists we set `config.flushInterval` otherwise we set the QueueTimer to use the `flushInterval` from the config
    
    public func configure(analytics: Analytics) {
        self.analytics = analytics
        
        if let desiredInterval = desiredInterval {
            analytics.flushInterval = desiredInterval
        }
        
        self.flushTimer = QueueTimer(interval: analytics.configuration.values.flushInterval) { [weak self] in
            self?.analytics?.flush()
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
