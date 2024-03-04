//
//  DataStore.swift
//
//
//  Created by Brandon Sneed on 11/27/23.
//

import Foundation


public struct DataResult {
    public let data: Data?
    public let dataFiles: [URL]?
    public let removable: [DataStore.HashValue]?
    
    public init(data: Data?, dataFiles: [URL]?, removable: [DataStore.HashValue]?) {
        self.data = data
        self.dataFiles = dataFiles
        self.removable = removable
    }
    
    public init(data: Data?, removable: [DataStore.HashValue]?) {
        self.init(data: data, dataFiles: nil, removable: removable)
    }
    
    public init(dataFiles: [URL]?, removable: [DataStore.HashValue]?) {
        self.init(data: nil, dataFiles: dataFiles, removable: removable)
    }
}

public protocol DataStore {
    typealias HashValue = Int
    associatedtype StoreConfiguration
    var hasData: Bool { get }
    var count: Int { get }
    init(configuration: StoreConfiguration)
    func reset()
    func append<T: Codable>(data: T)
    func fetch(count: Int?, maxBytes: Int?) -> DataResult?
    func remove(data: [HashValue])
}

extension Array where Element: Hashable {
    var hashValues: [DataStore.HashValue] {
        var result = [DataStore.HashValue]()
        for item in self {
            result.append(item.hashValue)
        }
        return result
    }
}
