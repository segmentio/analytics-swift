//
//  ObjectPath.swift
//  Segment
//
//  Created by Brandon Sneed on 3/19/21.
//

import Foundation

protocol KeyPathHandler {
    func isHandled(_ keyPath: KeyPath, forInput: Any?) -> Bool
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
    
    func isHandled(_ keyPath: KeyPath, forInput: Any?) -> Bool {
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
    
    internal static var handlers: [KeyPathHandler] = [PathHandler(), IfHandler(), BasicHandler()]
    static func register(_ handler: KeyPathHandler) { handlers.insert(handler, at: 0) }
    static func handlerFor(keyPath: KeyPath, input: Any?) -> KeyPathHandler? {
        guard let input = input as? [String: Any] else { return nil }
        for item in handlers {
            if item.isHandled(keyPath, forInput: input[keyPath.current]) {
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
        let handler = KeyPath.handlerFor(keyPath: keyPath, input: self)
        let result = handler?.value(keyPath: keyPath, input: self, reference: reference)
        return result
    }
    
    internal mutating func setValue(_ value: Any?, keyPath: KeyPath) {
        guard let key = keyPath.current as? Key else { return }
        
        if keyPath.remaining.isEmpty {
            if value.flattened() != nil {
                self[key] = (value as! Value)
            } else {
                self.removeValue(forKey: key)
            }
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

    public subscript(keyPath keyPath: KeyPath, reference reference: Any?) -> Any? {
        get { return value(keyPath: keyPath, reference: reference) }
        set { setValue(newValue as Any, keyPath: keyPath) }
    }
    
    public func exists(keyPath: KeyPath, reference: Any? = nil) -> Bool {
        return (value(keyPath: keyPath, reference: reference) != nil)
    }
}

extension String {
    internal var strippedReference: String {
        return self.replacingOccurrences(of: "$.", with: "")
    }
}

// @if, @path, @template


struct IfHandler: KeyPathHandler {
    func isHandled(_ keyPath: KeyPath, forInput: Any?) -> Bool {
        guard let input = forInput as? [String: Any] else { return false }
        if input["@if"] != nil { return true }
        return false
    }
    
    func value(keyPath: KeyPath, input: Any?, reference: Any?) -> Any? {
        guard let input = input as? [String: Any] else { return nil }
        let current = input[keyPath.current] as? [String: Any]
        let conditional = current?["@if"] as? [String: Any]
        
        let isBlank = conditional?["blank"] != nil
        let isExists = conditional?["exists"] != nil
        
        let blank = conditional?[keyPath: "blank", reference: reference]
        let exists = conditional?[keyPath: "exists", reference: reference]
        let then = conditional?[keyPath: "then", reference: reference]
        let elseCase = conditional?[keyPath: "else", reference: reference]
        
        var result: Any? = nil
        
        if isBlank {
            if blank == nil || blank as? String == "" {
                result = then
            } else {
                result = elseCase
            }
        } else if isExists {
            if exists != nil {
                result = then
            } else {
                result = elseCase
            }
        }
        
        return result
    }
    
}

struct PathHandler: KeyPathHandler {
    func isHandled(_ keyPath: KeyPath, forInput: Any?) -> Bool {
        guard let input = forInput as? [String: Any] else { return false }
        if input["@path"] != nil {
            return true
        }
        return false
    }
    
    func value(keyPath: KeyPath, input: Any?, reference: Any?) -> Any? {
        guard let input = input as? [String: Any] else { return nil }
        let current = input[keyPath.current] as? [String: Any]
        let path = (current?["@path"] as? String)?.strippedReference
        
        var result: Any? = nil
        if let path = path, let reference = reference as? [String: Any] {
            result = reference[keyPath: KeyPath(path)]
        }
        return result
    }
    
}
