//
//  JSONTests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/1/20.
//

import XCTest
@testable import Segment

struct Personal: Codable {
    let preferences: [String]
    let birthday: Date
}

class JSONTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testJSONBasic() throws {
        let traits = try? JSON(["email": "blah@blah.com"])
        let userInfo = UserInfo(anonymousId: "1234", userId: "brandon", traits: traits)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(userInfo)
            XCTAssertNotNil(json)
        } catch {
            print(error)
            XCTFail()
        }
    }
    
    func testJSONFromCodable() throws {
        struct TestStruct: Codable {
            let blah: String
        }
        
        let test = TestStruct(blah: "hello")
        let object = try JSON(with: test)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(object)
            XCTAssertNotNil(json)
        } catch {
            print(error)
            XCTFail()
        }
    }
    
    func testTypesFromJSON() throws {
        struct TestStruct: Codable {
            let str: String
            let bool: Bool
            let float: Float
            let int: Int
            let uint: UInt
            let double: Double
            let decimal: Decimal
            let array: JSON?
            let dict: JSON?
        }
        
        let test = TestStruct(
            str: "hello",
            bool: true,
            float: 3.14,
            int: -42,
            uint: 42,
            double: 1.234,
            decimal: 333.9999,
            array: try JSON(["1", "2"]),
            dict: try JSON(["1": 1, "2": 2])
        )
        
        let jsonObject = try JSON(with: test)
        XCTAssertNotNil(jsonObject)
        
        let typedDict = jsonObject.dictionaryValue
        XCTAssertNotNil(typedDict)
        
        let str = typedDict?["str"] as? String
        let bool = typedDict?["bool"] as? Bool
        #if os(Linux)
        // the linux implementation of Dictionary has
        // some issues w/ type conversion to float.
        let float = typedDict?["float"] as? Decimal
        #else
        let float = typedDict?["float"] as? Float
        #endif
        let int = typedDict?["int"] as? Int
        let uint = typedDict?["uint"] as? UInt
        let double = typedDict?["double"] as? Double
        let decimal = typedDict?["decimal"] as? Decimal
        let array = typedDict?["array"] as? [String]
        let dict = typedDict?["dict"] as? [String: Int]
        
        XCTAssertEqual(str, "hello")
        XCTAssertEqual(bool, true)
        XCTAssertEqual(float, 3.14)
        XCTAssertEqual(int, -42)
        XCTAssertEqual(uint, 42)
        XCTAssertEqual(double, 1.234)
        XCTAssertEqual(decimal, 333.9999)
        
        XCTAssertEqual(array?[0], "1")
        XCTAssertEqual(array?[1], "2")
        
        XCTAssertEqual(dict?["1"], 1)
        XCTAssertEqual(dict?["2"], 2)
    }
    
    func testCodableFetch() {
        let traits = MyTraits(email: "test@test.com")
        let json = try? JSON(with: traits)
        
        XCTAssertNotNil(json)
        
        let fetchedTraits: MyTraits? = json?.codableValue()
        
        XCTAssertTrue(fetchedTraits?.email == "test@test.com")
    }
    
    func testKeyMapping() {
        let keys = ["Key1": "AKey1", "Key2": "AKey2"]
        let dict: [String: Any] = ["Key1": 1, "Key2": 2, "Key3": 3, "Key4": ["Key1": 1]]
        
        let json = try! JSON(dict)
        
        let output = try! json.mapKeys(keys).dictionaryValue
        
        XCTAssertTrue(output!["AKey1"] as! Int == 1)
        XCTAssertTrue(output!["AKey2"] as! Int == 2)
        XCTAssertTrue(output!["Key3"] as! Int == 3)
        
        let subDict = output!["Key4"] as! [String: Any]
        XCTAssertTrue(subDict["AKey1"] as! Int == 1)
    }
    
    func testKeyMappingWithValueTransform() {
        let keys = ["Key1": "AKey1", "Key2": "AKey2"]
        let dict: [String: Any] = ["Key1": 1, "Key2": 2, "Key3": 3, "Key4": ["Key1": 1], "Key5": [1, 2, ["Key1": 1]]]
        
        let json = try! JSON(dict)
        
        let output = try! json.mapKeys(keys, valueTransform: { key, value in
            var newValue = value
            if let v = newValue as? Int {
                if v == 1 {
                    newValue = 11
                }
            }
            print("value = \(value.self)")
            return newValue
        }).dictionaryValue
        
        XCTAssertTrue(output!["AKey1"] as! Int == 11)
        XCTAssertTrue(output!["AKey2"] as! Int == 2)
        XCTAssertTrue(output!["Key3"] as! Int == 3)
        
        let subDict = output!["Key4"] as! [String: Any]
        XCTAssertTrue(subDict["AKey1"] as! Int == 11)
    }
}
