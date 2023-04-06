//
//  CountBasedFlushPolicy.swift
//  
//
//  Created by Alan Charles on 3/21/23.
//

import Foundation
import Sovran

public class CountBasedFlushPolicy: FlushPolicy {
    public var analytics: Analytics?
    internal var count: Int = 0
    internal var flushCount: Int = 20
    
    init() {}
    
    public func configure(analytics: Analytics) {
        self.analytics = analytics
        
      
        
    }
    
    public func shouldFlush() -> Bool {
        guard let a = analytics else {
            return false
        }
        print(count)
        if (count >=  a.configuration.values.flushAt) {
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
