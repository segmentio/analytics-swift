//
//  File.swift
//  
//
//  Created by Brandon Sneed on 11/27/23.
//

import Foundation

public class MemoryStore: DataStore {
    public typealias StoreConfiguration = Configuration
    
    public struct Configuration {
        let writeKey: String
        let maxItems: Int
        let maxFetchSize: Int
        
        public init(writeKey: String, maxItems: Int, maxFetchSize: Int) {
            self.writeKey = writeKey
            self.maxItems = maxItems
            self.maxFetchSize = maxFetchSize
        }
    }
    
    internal struct ItemData {
        let id: UUID
        let data: Data
        
        init(data: Data) {
            self.id = UUID()
            self.data = data
        }
    }
    
    internal var items = [ItemData]()
    
    public var hasData: Bool {
        return (items.count > 0)
    }
    
    public var count: Int {
        return items.count
    }
    
    public var transactionType: DataTransactionType {
        return .data
    }
    
    internal let config: Configuration
    
    public required init(configuration: Configuration) {
        self.config = configuration
    }
    
    public func reset() {
        items.removeAll()
    }
    
    public func append(data: RawEvent) {
        guard let d = data.toString().data(using: .utf8) else { return }
        items.append(ItemData(data: d))
        if items.count > config.maxItems {
            items.removeFirst()
        }
    }
    
    public func fetch(count: Int?, maxBytes: Int?) -> DataResult? {
        var accumulatedCount = 0
        var accumulatedSize: Int = 0
        var results = [ItemData]()
        
        let maxBytes = maxBytes ?? config.maxFetchSize
        
        for item in items {
            if accumulatedSize + item.data.count > maxBytes {
                break
            }
            if let count, accumulatedCount >= count {
                break
            }
            accumulatedCount += 1
            accumulatedSize += item.data.count
            results.append(item)
        }
        if results.count > 0 {
            let removable = results.map { item in
                return item.id
            }
            return DataResult(data: fullyFormedJSON(items: results), removable: removable)
        }
        return nil
    }
    
    public func remove(data: [DataStore.ItemID]) {
        items.removeAll { itemData in
            let present = data.contains { id in
                guard let id = id as? UUID else { return false }
                return itemData.id == id
            }
            return present
        }
    }
}

extension MemoryStore {
    internal func fullyFormedJSON(items: [ItemData]) -> Data? {
        guard items.count > 0 else { return nil }
        var json = Data()
        let start = "{ \"batch\": [".data(using: .utf8)!
        let end = "],\"sentAt\":\"\(Date().iso8601())\",\"writeKey\":\"\(config.writeKey)\"}".data(using: .utf8)!
        
        json.append(start)
        items.indices.forEach { index in
            if index == 0 {
                json.append(items[index].data)
            } else {
                json.append(",".data(using: .utf8)!)
                json.append(items[index].data)
            }
        }
        json.append(end)
        
        return json
    }
}

