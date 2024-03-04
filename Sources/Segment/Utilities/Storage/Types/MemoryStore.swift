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
    }
    
    internal var items = [Data]()
    
    public var hasData: Bool {
        return (items.count > 0)
    }
    
    public var count: Int {
        return items.count
    }
    
    internal let config: Configuration
    
    public required init(configuration: Configuration) {
        self.config = configuration
    }
    
    public func reset() {
        items.removeAll()
    }
    
    public func append<T: Codable>(data: T) {
        let encoder = JSONEncoder()
        guard let d = try? encoder.encode(data) else { return }
        items.append(d)
        if items.count >= config.maxItems {
            items.removeFirst()
        }
    }
    
    public func fetch(count: Int?, maxBytes: Int?) -> DataResult? {
        var accumulatedCount = 0
        var accumulatedSize: Int = 0
        var results = [Data]()
        
        let maxBytes = maxBytes ?? config.maxFetchSize
        
        for item in items {
            if accumulatedSize + item.count > maxBytes {
                break
            }
            if let count, accumulatedCount >= count {
                break
            }
            accumulatedCount += 1
            accumulatedSize += item.count
            results.append(item)
        }
        if results.count > 0 {
            return DataResult(data: fullyFormedJSON(items: results), removable: results.hashValues)
        }
        return nil
    }
    
    public func remove(data: [DataStore.HashValue]) {
        items = items.filter { item in
            return data.contains(item.hashValue)
        }
    }
}

extension MemoryStore {
    internal func fullyFormedJSON(items: [Data]) -> Data? {
        guard items.count > 0 else { return nil }
        var json = Data()
        let start = "{ \"batch\": [".data(using: .utf8)!
        let end = "],\"sentAt\":\"\(Date().iso8601())\",\"writeKey\":\"\(config.writeKey)\"}".data(using: .utf8)!
        
        json.append(start)
        items.indices.forEach { index in
            if index == 0 {
                json.append(items[index])
            } else {
                json.append(",".data(using: .utf8)!)
                json.append(items[index])
            }
        }
        json.append(end)
        
        return json
    }
}

