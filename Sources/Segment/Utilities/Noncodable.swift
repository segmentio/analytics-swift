//
//  Noncodable.swift
//  
//
//  Created by Brandon Sneed on 4/17/24.
//

import Foundation

@propertyWrapper
public struct Noncodable<T>: Codable {
    public var wrappedValue: T?
    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
    public init(from decoder: Decoder) throws {
        self.wrappedValue = nil
    }
    public func encode(to encoder: Encoder) throws {
        // Do nothing
    }
}

extension KeyedDecodingContainer {
    internal func decode<T>(_ type: Noncodable<T>.Type, forKey key: Self.Key) throws -> Noncodable<T> {
        return Noncodable(wrappedValue: nil)
    }
}

extension KeyedEncodingContainer {
    internal mutating func encode<T>(_ value: Noncodable<T>, forKey key: KeyedEncodingContainer<K>.Key) throws {
        // Do nothing
    }
}
