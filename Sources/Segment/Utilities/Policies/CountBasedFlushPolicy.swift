//
//  CountBasedFlushPolicy.swift
//  
//
//  Created by Alan Charles on 3/21/23.
//

import Foundation

public class CountBasedFlushPolicy: FlushPolicy {
    public weak var analytics: Analytics?
    internal var desiredCount: Int?
    @Atomic internal var count: Int = 0
    
    init() { }
    
    init(count: Int) {
        desiredCount = count
    }
    
    public func configure(analytics: Analytics) {
        self.analytics = analytics
        if let desiredCount = desiredCount {
            analytics.flushAt = desiredCount
        }
    }
    
    public func shouldFlush() -> Bool {
        guard let a = analytics else {
            return false
        }
        if a.configuration.values.flushAt > 0 && count >= a.configuration.values.flushAt {
            return true
        } else {
            return false
        }
    }
    
   public func updateState(event: RawEvent) {
        count += 1
    }
    
    public func reset() {
        count = 0
    }
}
