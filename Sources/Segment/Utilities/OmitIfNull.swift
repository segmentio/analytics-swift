//
//  OmitIfNull.swift
//  Segment
//
//  Created by Brandon Sneed on 3/11/25.
//

@propertyWrapper
public struct OmitIfNull<T: Codable>: Codable {
    public var wrappedValue: T?
    
    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = wrappedValue {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}

extension KeyedEncodingContainer {
    internal mutating func encode<T>(_ value: OmitIfNull<T>, forKey key: Key) throws where T: Encodable {
        if value.wrappedValue != nil {
            try encode(value.wrappedValue, forKey: key)
        }
    }
}
