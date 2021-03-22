//
//  ObjectPath.swift
//  Segment
//
//  Created by Brandon Sneed on 3/19/21.
//

import Foundation

protocol KeyPathHandler {
    func isHandled(_ keyPath: KeyPath) -> Bool
    func value(keyPath: KeyPath, input: Any?, reference: Any?) -> Any?
}

public struct BasicHandler: KeyPathHandler {
    func value(keyPath: KeyPath, input: Any?, reference: Any?) -> Any? {
        guard let input = input as? [String: Any] else { return nil }
        var result: Any? = nil
        if keyPath.remaining.isEmpty {
            result = input[keyPath.current]
        } else {
            if let nestedDict = input[keyPath.current] as? [String: Any] {
                result = nestedDict[keyPath: KeyPath(keyPath.remainingPath)]
            } else {
                result = nil
            }
        }
        return result
    }
    
    func isHandled(_ keyPath: KeyPath) -> Bool {
        return true
    }
}

public struct KeyPath {
    var current: String
    var remaining: [String]
    
    var remainingPath: String { return remaining.joined(separator: ".") }

    public init(_ string: String) {
        var components = string.components(separatedBy: ".")
        current = components.removeFirst()
        remaining = components
    }
    
    internal static var handlers: [KeyPathHandler] = [BasicHandler()]
    static func register(_ handler: KeyPathHandler) { handlers.insert(handler, at: 0) }
    static func handlerFor(keyPath: KeyPath) -> KeyPathHandler? {
        for item in handlers {
            if item.isHandled(keyPath) {
                return item
            }
        }
        return nil
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
    internal func value(keyPath: KeyPath, reference: Any?) -> Any? {
        let handler = KeyPath.handlerFor(keyPath: keyPath)
        let result = handler?.value(keyPath: keyPath, input: self, reference: reference)
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
        get { return value(keyPath: keyPath, reference: nil) }
        set { setValue(newValue as Any, keyPath: keyPath) }
    }

    public subscript(keyPath keyPath: KeyPath, reference: Any?) -> Any? {
        get { return value(keyPath: keyPath, reference: reference) }
        set { setValue(newValue as Any, keyPath: keyPath) }
    }
}

// @if, @path, @template


struct IfHandler: KeyPathHandler {
    func isHandled(_ keyPath: KeyPath) -> Bool {
        if keyPath.current == "@if" { return true }
        return false
    }
    
    func value(keyPath: KeyPath, input: Any?, reference: Any?) -> Any? {
        return nil
    }
    
}
