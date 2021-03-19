//
//  ObjectPath.swift
//  Segment
//
//  Created by Brandon Sneed on 3/19/21.
//

import Foundation

public struct KeyPath {
    var current: String
    var remaining: [String]
    
    var remainingPath: String { return remaining.joined(separator: ".") }

    public init(_ string: String) {
        var components = string.components(separatedBy: ".")
        current = components.removeFirst()
        remaining = components
    }
}

extension KeyPath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
    public init(unicodeScalarLiteral value: String) {
        self.init(value)
    }
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }
}

extension Dictionary where Key: StringProtocol, Value: Any {
    internal func value(keyPath: KeyPath) -> Any? {
        var result: Any? = nil
        guard let key = keyPath.current as? Key else { return nil }
        
        if keyPath.remaining.isEmpty {
            result = self[key]
        } else {
            if let nestedDict = self[key] as? [String: Any] {
                result = nestedDict[keyPath: KeyPath(keyPath.remainingPath)]
            } else {
                result = nil
            }
        }
        return result
    }
    
    internal mutating func setValue(_ value: Any, keyPath: KeyPath) {
        guard let key = keyPath.current as? Key else { return }
        
        if keyPath.remaining.isEmpty {
            self[key] = (value as! Value)
        } else {
            if var nestedDict = self[key] as? [String: Any] {
                nestedDict[keyPath: KeyPath(keyPath.remainingPath)] = value
                self[key] = (nestedDict as! Value)
            } else {
                // this nested key doesn't exist but we're not at the end of the chain, need to create it
                var nestedDict = [String: Any]()
                nestedDict[keyPath: KeyPath(keyPath.remainingPath)] = value
                self[key] = (nestedDict as! Value)
            }
        }
    }
    
    public subscript(keyPath keyPath: KeyPath) -> Any? {
        get {
            return value(keyPath: keyPath)
        }
        
        set {
            setValue(newValue as Any, keyPath: keyPath)
        }
    }
}
