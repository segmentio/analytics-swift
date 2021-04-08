//
//  Atomic.swift
//  Segment
//
//  Created by Brandon Sneed on 4/8/21.
//

import Foundation

@propertyWrapper
internal struct Atomic<T> {
    private var value: T
    private let lock = NSLock()

    init(wrappedValue value: T) {
        self.value = value
    }

    var wrappedValue: T {
      get { return load() }
      set { store(newValue: newValue) }
    }

    func load() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    mutating func store(newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
