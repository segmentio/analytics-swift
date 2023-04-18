//
//  JSON.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/2/20.
//

import Foundation


// MARK: - JSON Definition

public enum JSON: Equatable {
    case null
    case bool(Bool)
    case number(Decimal)
    case string(String)
    case array([JSON])
    case object([String: JSON])
    
    internal enum JSONError: Error {
        case unknown
        case nonJSONType(type: String)
        case incorrectType
    }
    
    public init(_ object: [String: Any]) throws {
        self = .object(try object.mapValues(JSON.init))
    }
    
    public init?(nilOrObject object: [String: Any]?) throws {
        guard let object = object else { return nil }
        try self.init(object)
    }
    
    // For Value types
    public init<T: Codable>(with value: T) throws {
        let encoder = JSONEncoder()
        let json = try encoder.encode(value)
        let output = try JSONSerialization.jsonObject(with: json)
        try self.init(output)
    }
    
    // For primitives??
    public init(_ value: Any) throws {
        switch value {
        // handle NS values
        case _ as NSNull:
            self = .null
        case let number as NSNumber:
            // need to see if it's a bool or not
            if number.isBool() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.decimalValue)
            }
            
        // handle swift types
        case Optional<Any>.none:
            self = .null
        case let url as URL:
            self = .string(url.absoluteString)
        case let string as String:
            self = .string(string)
        case let bool as Bool:
            self = .bool(bool)
        case let aSet as Set<AnyHashable>:
            self = .array(try aSet.map(JSON.init))
        case let array as Array<Any>:
            self = .array(try array.map(JSON.init))
        case let object as [String: Any]:
            self = .object(try object.mapValues(JSON.init))
        case let json as JSON:
            self = json
        // we don't work with whatever is being supplied
        default:
            throw JSONError.nonJSONType(type: "\(value.self)")
        }
    }
}


// MARK: - Codable conformance

extension JSON: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(bool):
            try container.encode(bool)
        case let .number(number):
            try container.encode(number)
        case let .string(string):
            try container.encode(string)
        case let .array(array):
            try container.encode(array)
        case let .object(object):
            try container.encode(object)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Decimal.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSON].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSON].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value!")
        }
    }
}

extension Encodable {
    public func prettyPrint() -> String {
        return toString(pretty: true)
    }
    
    public func toString() -> String {
        return toString(pretty: false)
    }
    
    public func toString(pretty: Bool) -> String {
        var returnString = ""
        do {
            let encoder = JSONEncoder()
            if pretty {
                encoder.outputFormatting = .prettyPrinted
            }

            let json = try encoder.encode(self)
            if let printed = String(data: json, encoding: .utf8) {
                returnString = printed
            }
        } catch {
            returnString = error.localizedDescription
        }
        return returnString
    }
}


// MARK: - Value Extraction & Conformance

extension JSON {
    private func rawValue() -> Any {
        var result: Any? = nil
        switch self {
        case .null:
            result = NSNull()
        case .bool(let value):
            result = value
        case .number(let value):
            // automatic type conversion between number types
            // fails if this isn't typecast to NSDecimalNumber first.
            result = value as NSDecimalNumber
        case .string(let value):
            result = value
        case .array(let value):
            result = value.map { item in
                return item.rawValue()
            }
        case .object(let value):
            result = value.mapValues { item in
                return item.rawValue()
            }
        }
        return result as Any
    }
    
    public func codableValue<T: Codable>() -> T? {
        var result: T? = nil
        if let dict = dictionaryValue, let jsonData = try? JSONSerialization.data(withJSONObject: dict) {
            result = try? JSONDecoder().decode(T.self, from: jsonData)
        }
        return result
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        default:
            return nil
        }
    }
    
    public var decimalValue: Decimal? {
        switch self {
        case .number(let value):
            return value
        default:
            return nil
        }
    }
    
    public var intValue: Int? {
        switch self {
        case .number(let value):
            return (value as NSDecimalNumber).intValue
        default:
            return nil
        }
    }
    
    public var uintValue: UInt? {
        switch self {
        case .number(let value):
            return (value as NSDecimalNumber).uintValue
        default:
            return nil
        }
    }
    
    public var floatValue: Float? {
        switch self {
        case .number(let value):
            return (value as NSDecimalNumber).floatValue
        default:
            return nil
        }
    }
    
    public var doubleValue: Double? {
        switch self {
        case .number(let value):
            return (value as NSDecimalNumber).doubleValue
        default:
            return nil
        }
    }
    
    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
    
    public var arrayValue: [Any]? {
        switch self {
        case .array(let value):
            let result = value.map { item in
                return item.rawValue()
            }
            return result
        default:
            return nil
        }
    }
    

    public var dictionaryValue: [String: Any]? {
        switch self {
        case .object(let value):
            let result = value.mapValues { item in
                return item.rawValue()
            }
            return result
        default:
            return nil
        }
    }
}

// MARK: - Mutation

extension JSON {
    /// Maps keys supplied, in the format of ["Old": "New"].  Gives an optional value transformer that can be used to transform values based on the final key name.
    /// - Parameters:
    ///   - keys: A dictionary containing key mappings, in the format of ["Old": "New"].
    ///   - valueTransform: An optional value transform closure.  Key represents the new key name.
    ///
    /// - Returns: A new JSON object with the specified changes.
    /// - Throws: This method will throw if transformation or JSON cannot be properly completed.
    public func mapTransform(_ keys: [String: String], valueTransform: ((_ key: String, _ value: Any) -> Any)? = nil) throws -> JSON {
        guard let dict = self.dictionaryValue else { return self }
        let mapped = try dict.mapTransform(keys, valueTransform: valueTransform)
        let result = try JSON(mapped)
        return result
    }
    
    /// Adds a new value to an array and returns a new JSON object.  Function will throw if value cannot be serialized.
    /// - Parameters:
    ///   - value: Value to add to the JSON array.
    ///
    /// - Returns: A new JSON array with the supplied value added.
    /// - Throws: This method throws when a value is added and unable to be serialized.
    public func add(value: Any) throws -> JSON? {
        var result: JSON? = nil
        switch self {
        case .array:
            var newArray = [Any]()
            if let existing = arrayValue {
                newArray.append(contentsOf: existing)
            }
            newArray.append(value)
            result = try JSON(newArray)
        default:
            throw JSONError.incorrectType
        }
        return result
    }
    
    /// Adds a new key, value pair to and returns a new JSON object.  Function will throw if value cannot be serialized.
    /// - Parameters:
    ///   - value: Value to add to the JSON array.
    ///   - forKey: The key name of the given value.
    ///
    /// - Returns: A new JSON object with the supplied Key/Value added.
    /// - Throws: This method throws when a value is added and unable to be serialized.
    public func add(value: Any, forKey key: String) throws -> JSON? {
        var result: JSON? = nil
        switch self {
        case .object:
            var newObject = [String: Any]()
            if let existing = dictionaryValue {
                newObject = existing
            }
            newObject[key] = value
            result = try JSON(newObject)
        default:
            throw JSONError.incorrectType
        }
        return result
    }
    
    /// Removes the key and associated value pair from this JSON object.
    /// - Parameters:
    ///   - key: The key of the value to be removed.
    ///
    /// - Returns: A new JSON object with the specified key and it's associated value removed.
    /// - Throws: This method throws when after modification, it is unable to be serialized.
    public func remove(key: String) throws -> JSON? {
        var result: JSON? = nil
        switch self {
        case .object:
            var newObject = [String: Any]()
            if let existing = dictionaryValue {
                newObject = existing
            }
            newObject.removeValue(forKey: key)
            result = try JSON(newObject)
        default:
            throw JSONError.incorrectType
        }
        return result

    }
        
    /// Directly access a specific index in the JSON array.
    public subscript(index: Int) -> JSON? {
        get {
            switch self {
            case .array(let value):
                if index < value.count {
                    let v = value[index]
                    return v
                }
            default:
                break
            }
            return nil
        }
    }
    
    /// Directly access a key within the JSON object.
    public subscript(key: String) -> JSON? {
        get {
            switch self {
            case .object(let value):
                return value[key]
            default:
                break
            }
            return nil
        }
    }

    /// Directly access or set a value within the JSON object using a key path.
    public subscript<T: Codable>(keyPath keyPath: KeyPath) -> T? {
        get {
            var result: T? = nil
            switch self {
            case .object:
                var value: Any? = nil
                if let dict = dictionaryValue {
                    value = dict[keyPath: keyPath]
                    if let v = value as? [String: Any] {
                        if let jsonData = try? JSONSerialization.data(withJSONObject: v) {
                            do {
                                result = try JSONDecoder().decode(T.self, from: jsonData)
                            } catch {
                                Analytics.segmentLog(message: "Unable to decode object (\(keyPath)) to a Codable: \(error)", kind: .error)
                            }
                        }
                        if result == nil {
                            result = v as? T
                        }
                    } else {
                        result = value as? T
                    }
                }
            default:
                break
            }
            return result
        }
        
        set(newValue) {
            switch self {
            case .object:
                if var dict: [String: Any] = dictionaryValue {
                    var json: JSON? = try? JSON(newValue as Any)
                    if json == nil {
                        json = try? JSON(with: newValue)
                    }
                    
                    if let json = json {
                        dict[keyPath: keyPath] = json
                        if let newSelf = try? JSON(dict) {
                            self = newSelf
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    /// Directly access a value within the JSON object using a key path.
    /// - Parameters:
    ///   - forKeyPath: The keypath within the object to retrieve.  eg: `context.device.ip`
    ///
    /// - Returns: The value as typed, or nil.
    public func value<T: Codable>(forKeyPath keyPath: KeyPath) -> T? {
        return self[keyPath: keyPath]
    }
    
    /// Directly access a value within the JSON object using a key path.
    /// - Parameters:
    ///   - forKeyPath: The keypath within the object to set.  eg: `context.device.ip`
    public mutating func setValue<T: Codable>(_ value: T?, forKeyPath keyPath: KeyPath) {
        self[keyPath: keyPath] = value
    }

}

// MARK: - Helpers

extension Dictionary where Key == String, Value == Any {
    public func mapTransform(_ keys: [String: String], valueTransform: ((_ key: Key, _ value: Value) -> Any)? = nil) throws -> [Key: Value] {
        let mapped = Dictionary(uniqueKeysWithValues: self.map { key, value -> (Key, Value) in
            var newKey = key
            var newValue = value
            
            // does this key have a mapping?
            if keys.keys.contains(key) {
                if let mappedKey = keys[key] {
                    // if so, lets change the key to the new value.
                    newKey = mappedKey
                }
            }
            // is this value a dictionary?
            if let dictValue = value as? [Key: Value] {
                if let r = try? dictValue.mapTransform(keys, valueTransform: valueTransform) {
                    // if so, lets recurse...
                    newValue = r
                }
            } else if let arrayValue = value as? [Value] {
                // if it's an array, we need to see if any dictionaries are within and process
                // those as well.
                newValue = arrayValue.map { item -> Value in
                    var newValue = item
                    if let dictValue = item as? [Key: Value] {
                        if let r = try? dictValue.mapTransform(keys, valueTransform: valueTransform) {
                            newValue = r
                        }
                    }
                    return newValue
                }
            }
            
            if !(newValue is [Key: Value]), let transform = valueTransform {
                // it's not a dictionary so apply our transform.
                
                // note: if it's an array, we've processed any dictionaries inside
                // already, but this gives the opportunity to apply a transform to the other
                // items in the array that weren't dictionaries.
                newValue = transform(newKey, newValue)
            }
            
            return (newKey, newValue)
        })
        
        return mapped
    }
}


fileprivate extension NSNumber {
    static let trueValue = NSNumber(value: true)
    static let trueObjCType = trueValue.objCType
    static let falseValue = NSNumber(value: false)
    static let falseObjCType = falseValue.objCType
    
    func isBool() -> Bool {
        let type = self.objCType
        if (compare(NSNumber.trueValue) == .orderedSame && type == NSNumber.trueObjCType) ||
           (compare(NSNumber.falseValue) == .orderedSame && type == NSNumber.falseObjCType) {
            return true
        }
        return false
    }
}

