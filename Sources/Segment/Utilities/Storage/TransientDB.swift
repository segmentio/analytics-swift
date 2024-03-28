//
//  TransientDB.swift
//
//
//  Created by Brandon Sneed on 11/27/23.
//
import Foundation

public class TransientDB {
    // our data store
    internal let store: any DataStore
    // keeps items added in the order given.
    internal let syncQueue = DispatchQueue(label: "transientDB.sync")
    private let asyncAppend: Bool
    
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
    
    public var transactionType: DataTransactionType {
        return store.transactionType
    }
    
    public init(store: any DataStore, asyncAppend: Bool = true) {
        self.store = store
        self.asyncAppend = asyncAppend
    }
    
    public func reset() {
        syncQueue.sync {
            store.reset()
        }
    }
    
    public func append(data: RawEvent) {
        if asyncAppend {
            syncQueue.async { [weak self] in
                guard let self else { return }
                store.append(data: data)
            }
        } else {
            syncQueue.sync { [weak self] in
                guard let self else { return }
                store.append(data: data)
            }
        }
    }
    
    public func fetch(count: Int? = nil, maxBytes: Int? = nil) -> DataResult? {
        var result: DataResult? = nil
        syncQueue.sync {
            result = store.fetch(count: count, maxBytes: maxBytes)
        }
        return result
    }
    
    public func remove(data: [DataStore.ItemID]) {
        syncQueue.sync {
            store.remove(data: data)
        }
    }
}
