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
    
    private enum JSONError: Error {
        case unknown
        case nonJSONType(type: String)
    }
    
    public init(_ object: [String: Any]) throws {
        self = .object(try object.mapValues(JSON.init))
    }
    
    public init<T: Codable>(_ value: T) throws {
        let encoder = JSONEncoder()
        let json = try encoder.encode(value)
        let output = try JSONSerialization.jsonObject(with: json)
        try self.init(output)
    }
    
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
        case nil:
            self = .null
        case let string as String:
            self = .string(string)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            self = .array(try array.map(JSON.init))
        case let object as [String: Any]:
            self = .object(try object.mapValues(JSON.init))
        
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
        var returnString = ""
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

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
