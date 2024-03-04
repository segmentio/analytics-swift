//
//  TransientDB.swift
//
//
//  Created by Brandon Sneed on 11/27/23.
//
import Foundation

internal class TransientDB {
    // our data store
    internal let store: any DataStore
    // keeps items added in the order given.
    internal let syncQueue = DispatchQueue(label: "transientDB.sync")
    // makes accessing count safe and mostly accurate.
    internal let countLock = NSLock()
    
    public var hasData: Bool {
        var result: Bool = false
        syncQueue.sync {
            result = store.hasData
        }
        return result
    }
    
    public var count: Int {
        var result: Int = 0
        syncQueue.sync {
            result = store.count
        }
        return result
    }
    
    public init(store: any DataStore) {
        self.store = store
    }
    
    public func reset() {
        syncQueue.sync {
            store.reset()
        }
    }
    
    public func append(data: Codable) {
        syncQueue.async { [weak self] in
            guard let self else { return }
            countLock.lock()
            store.append(data: data)
            countLock.unlock()
        }
    }
    
    public func fetch(count: Int? = nil, maxBytes: Int? = nil) -> DataResult? {
        var result: DataResult? = nil
        syncQueue.sync { [weak self] in
            guard let self else { return }
            result = store.fetch(count: count, maxBytes: maxBytes)
        }
        return result
    }
    
    public func remove(data: [DataStore.HashValue]) {
        syncQueue.sync {
            store.remove(data: data)
        }
    }
}
