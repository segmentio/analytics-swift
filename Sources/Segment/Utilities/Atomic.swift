//
//  Atomic.swift
//  Segment
//
//  Created by Brandon Sneed on 4/8/21.
//

import Foundation

/*
 Revised the implementation yet again.  Tiziano Coriano noticed that this wrapper
 can be misleading about it's atomicity.  A single set would be atomic, but a compound
 operation like += would cause an atomic read, and a separate atomic write, in which
 point another thread could've changed the value we're now working off of.
 
 This implementation removes the ability to set wrappedValue, and callers now must use
 the set() or mutate() functions explicitly to ensure a proper atomic mutation.
 
 The use of a dispatch queue was also removed in favor of an unfair lock (yes, it's
 implemented correctly).
 */

@propertyWrapper
public class Atomic<T> {
    #if os(Linux) || os(Windows)
    let swiftLock: NSLock
    #else
    internal typealias os_unfair_lock_t = UnsafeMutablePointer<os_unfair_lock_s>
    internal var unfairLock: os_unfair_lock_t
    #endif
    
    internal var value: T
    
    public init(wrappedValue value: T) {
        #if os(Linux) || os(Windows)
        self.swiftLock = NSLock()
        #else
        self.unfairLock = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
        self.unfairLock.initialize(to: os_unfair_lock())
        #endif
        self.value = value
    }
    
    deinit {
        #if !os(Linux) && !os(Windows)
        unfairLock.deallocate()
        #endif
    }
    
    public var wrappedValue: T {
        get {
            lock()
            defer { unlock() }
            return value
        }
        // set is not allowed, use set() or mutate()
    }
    
    public func set(_ newValue: T) {
        mutate { $0 = newValue }
    }
    
    public func mutate(_ mutation: (inout T) -> Void) {
        lock()
        defer { unlock() }
        mutation(&value)
    }
}

extension Atomic {
    internal func lock() {
        #if os(Linux) || os(Windows)
        swiftLock.lock()
        #else
        os_unfair_lock_lock(unfairLock)
        #endif
    }
    
    internal func unlock() {
        #if os(Linux) || os(Windows)
        swiftLock.unlock()
        #else
        os_unfair_lock_unlock(unfairLock)
        #endif
    }
}
