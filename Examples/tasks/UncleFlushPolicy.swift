//
//  UncleFlushPolicy.swift
//  Segment
//
//  Created by Brandon Sneed on 9/17/24.
//

import Foundation

public class UncleFlushPolicy: FlushPolicy {
    public weak var analytics: Analytics?
    internal var basePolicies: [FlushPolicy] = [CountBasedFlushPolicy(), IntervalBasedFlushPolicy(), /* .. add your own here .. */]
    
    public init() {
        /*
         or add your own here ...
         
         ```
         self.basePolicies.append(MyCrazyUnclesOtherPolicy(onThanksgiving: true)
         ```
         */
    }
    
    private func shouldWeREALLYFlush() -> Bool {
        // do some meaningful calculation or check here.
        // Ol Unc's was right i guess since we're gonna do what he says.
        return true
    }
    
    public func configure(analytics: Analytics) {
        self.analytics = analytics
        basePolicies.forEach { $0.configure(analytics: analytics) }
    }
    
    public func shouldFlush() -> Bool {
        guard let a = analytics else {
            return false
        }
        
        var shouldFlush = false
        for policy in basePolicies {
            shouldFlush = policy.shouldFlush() || shouldFlush
        }
        
        if shouldFlush {
            // ask the know it all ...
            shouldFlush = shouldWeREALLYFlush()
        }
        
        return shouldFlush
    }
    
    public func updateState(event: RawEvent) {
        basePolicies.forEach { $0.updateState(event: event) }
    }
    
    public func reset() {
        basePolicies.forEach { $0.reset() }
    }
}
