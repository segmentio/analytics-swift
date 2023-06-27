//
//  Atomic.swift
//  Segment
//
//  Created by Brandon Sneed on 4/8/21.
//

import Foundation

// NOTE: Revised from previous implementation which used a struct and NSLock's.
// Thread Sanitizer was *correctly* capturing this issue, which was a little obscure
// given the property wrapper PLUS the semantics of a struct.  Moving to `class`
// removes the semantics problem and lets TSan approve of what's happening.
//
// Additionally, moving to a lock free version is just desirable, so moved to a queue.
//
// Also see thread here: https://github.com/apple/swift-evolution/pull/1387

@propertyWrapper
public class Atomic<T> {
    private var value: T
    private let queue = DispatchQueue(label: "com.segment.atomic.\(UUID().uuidString)")

    public init(wrappedValue value: T) {
        self.value = value
    }

    public var wrappedValue: T {
        get { return queue.sync { return value } }
        set { queue.sync { value = newValue } }
    }
}
