//
//  FlushPolicy.swift
//  
//
//  Created by Alan Charles on 3/21/23.
//

import Foundation


public protocol FlushPolicy {
    var analytics: Analytics? { get set }

    func configure(analytics: Analytics) -> Void
    func shouldFlush() -> Bool
    func updateState(event: RawEvent) -> Void
    func reset() -> Void
}

public extension Analytics {
    func add(flushPolicy: FlushPolicy) {
        
    }
    
    func remove(flushPolicy: FlushPolicy) {
        
    }
    
    func removeAll() {
        
    }
    
    func find(flushPolicy: FlushPolicy.Type) -> FlushPolicy? {
        return nil
    }
 }
