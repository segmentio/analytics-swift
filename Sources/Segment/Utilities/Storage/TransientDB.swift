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
    // tracks pending async dispatches to prevent race conditions during flush
    private let pendingAppends = DispatchGroup()

    public var hasData: Bool {
        // Wait for all pending async dispatches before checking
        pendingAppends.wait()
        var result: Bool = false
        syncQueue.sync {
            result = store.hasData
        }
        return result
    }

    public var count: Int {
        // Wait for all pending async dispatches before counting
        pendingAppends.wait()
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
            // Track pending operation before dispatching
            pendingAppends.enter()
            // Dispatch to background thread, but execute synchronously on syncQueue
            // This ensures FIFO ordering while keeping appends off the main thread
            DispatchQueue.global(qos: .utility).async { [weak self] in
                defer { self?.pendingAppends.leave() }
                self?.syncQueue.sync { [weak self] in
                    guard let self else { return }
                    store.append(data: data)
                }
            }
        } else {
            syncQueue.sync { [weak self] in
                guard let self else { return }
                store.append(data: data)
            }
        }
    }
    
    public func fetch(count: Int? = nil, maxBytes: Int? = nil) -> DataResult? {
        // Wait for all pending async dispatches to reach syncQueue
        // This prevents race condition where fetch() runs before appends are queued
        pendingAppends.wait()

        // syncQueue is serial and all operations use .sync, ensuring FIFO ordering
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
