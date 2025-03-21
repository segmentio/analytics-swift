//
//  JSONTests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/1/20.
//

import XCTest
import JSONSafeEncoding
@testable import Segment

struct Personal: Codable {
    let preferences: [String]
    let birthday: Date?
    let type: String?
}

struct TestStruct: Codable {
    let str: String
    let bool: Bool
    let int: Int
    let uint: UInt
    let double: Double
    let decimal: Decimal
    let array: JSON?
    let dict: JSON?
}

class JSONTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testJSONBasic() throws {
        let traits = try! JSON(["email": "blah@blah.com"])
        let userInfo = UserInfo(anonymousId: "1234", userId: "brandon", traits: traits, referrer: nil)
        
        let encoder = JSONSafeEncoder.default
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(userInfo)
            XCTAssertNotNil(json)
        } catch {
            print(error)
            XCTFail()
        }
    }
    
    func testJSONDateHandling() throws {
        struct TestStruct: Codable {
            let myDate: Date
        }

        let expectedDateString = "2023-12-14T16:03:14.300Z"
        let expectedDate = try XCTUnwrap(expectedDateString.iso8601())

        let test = TestStruct(myDate: expectedDate)
        let object = try JSON(with: test)
        let encoder = JSONSafeEncoder.default
        encoder.outputFormatting = .prettyPrinted

        do {
            let json = try encoder.encode(object)
            XCTAssertNotNil(json)
            let newTest = try! JSONDecoder.default.decode(TestStruct.self, from: json)
            XCTAssertEqual(newTest.myDate.toString(), "\"\(expectedDateString)\"")
        } catch {
            print(error)
            XCTFail()
        }

        let dummyProps = ["myDate": expectedDate] // <- conforms to Codable
        let j = try! JSON(dummyProps)
        let anotherTest: TestStruct! = j.codableValue()
        XCTAssertEqual(anotherTest.myDate.toString(), "\"\(expectedDateString)\"")

        // Non-Codable (e.g., Objective-C) interface

        let dictWithDate = ["myDate": expectedDate]
        let json = try JSON(dictWithDate)
        let value = json["myDate"]

        guard case .string(let actualDateString) = value else {
            XCTFail()
            return
        }

        XCTAssertEqual(expectedDateString, actualDateString)
    }
    
    func testJSONCollectionTypes() throws {
        let testSet: Set = ["1", "2", "3"]
        let traits = try! JSON(["type": NSNull(), "preferences": ["bwack"], "key": testSet])
        let jsonSet = traits["key"]
        XCTAssertNotNil(jsonSet)
        let array = jsonSet!.arrayValue!
        XCTAssertNotNil(array)
        XCTAssertEqual(array.count, 3)
    }
    
    func testJSONNil() throws {
        let traits = try JSON(["type": NSNull(), "preferences": ["bwack"], "key": nil] as [String : Any?])
        let encoder = JSONSafeEncoder.default
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(traits)
            XCTAssertNotNil(json)
            let decoded = try JSONDecoder.default.decode(Personal.self, from: json)
            XCTAssertNil(decoded.type, "Type should be nil")
        }
    }
    
    func testJSONFromCodable() throws {
        struct TestStruct: Codable {
            let blah: String
        }
        
        let test = TestStruct(blah: "hello")
        let object = try JSON(with: test)
        let encoder = JSONSafeEncoder.default
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(object)
            XCTAssertNotNil(json)
        } catch {
            print(error)
            XCTFail()
        }
    }
    
    func testJSONMutation() throws {
        let test = TestStruct(
            str: "hello",
            bool: true,
            int: -42,
            uint: 42,
            double: 1.234,
            decimal: 333.9999,
            array: try JSON(["1", "2"]),
            dict: try JSON(["1": 1, "2": 2])
        )
        
        let wrapper: [String: Any] = [
            "name": "Brandon",
            "someValue": 42,
            "test": try JSON(with: test)
        ]
        
        var jsonObject = try JSON(wrapper)
        XCTAssertNotNil(jsonObject)
        
        // wrapping a JSON object with another results in a no-op.
        let jsonObject2 = try JSON(jsonObject)
        XCTAssertNotNil(jsonObject2)
        
        let structValue: TestStruct? = jsonObject[keyPath: "test"]
        XCTAssertEqual(structValue!.str, "hello")

        let intValue: Int? = jsonObject[keyPath: "test.dict.1"]
        XCTAssertEqual(intValue, 1)
        
        jsonObject[keyPath: "structSet.object"] = test
        jsonObject[keyPath: "codys.brain.melted"] = true
        
        XCTAssertTrue(jsonObject[keyPath: "structSet.object.str"] == "hello")
        XCTAssertTrue(jsonObject[keyPath: "codys.brain.melted"] == true)
        
        let dubz: Double? = jsonObject.value(forKeyPath: "structSet.object.double")
        XCTAssertEqual(dubz, 1.234)
        
        jsonObject.setValue(47, forKeyPath: "test.uint")
        XCTAssertEqual(jsonObject[keyPath: "test.uint"], 47)
    }
    
    func testTypesFromJSON() throws {
        let test = TestStruct(
            str: "hello",
            bool: true,
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
        let int = typedDict?["int"] as? Int
        let uint = typedDict?["uint"] as? UInt
        let double = typedDict?["double"] as? Double
        let decimal = typedDict?["decimal"] as? Decimal
        let array = typedDict?["array"] as? [String]
        let dict = typedDict?["dict"] as? [String: Int]
        
        XCTAssertEqual(str, "hello")
        XCTAssertEqual(bool, true)
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
        
        let output = try! json.mapTransform(keys).dictionaryValue
        
        XCTAssertTrue(output!["AKey1"] as! Int == 1)
        XCTAssertTrue(output!["AKey2"] as! Int == 2)
        XCTAssertTrue(output!["Key3"] as! Int == 3)
        
        let subDict = output!["Key4"] as! [String: Any]
        XCTAssertTrue(subDict["AKey1"] as! Int == 1)
    }
    
    func testKeyMappingWithValueTransform() {
        let keys = ["Key1": "AKey1", "Key2": "AKey2"]
        let dict: [String: Any] = ["Key1": 1, "Key2": 2, "Key3": 3, "Key4": ["Key1": 1], "Key5": [1, 2, ["Key1": 1]] as [Any]]
        
        let json = try! JSON(dict)
        
        let output = try! json.mapTransform(keys, valueTransform: { key, value in
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
        
        let subArray = output!["Key5"] as! [Any]
        let subArrayDict = subArray[2] as! [String: Any]
        XCTAssertTrue(subArray[0] as! Int == 1)
        XCTAssertTrue(subArray[1] as! Int == 2)
        XCTAssertTrue(subArrayDict["AKey1"] as! Int == 11)
    }
    
    func testAddRemoveValues() {
        struct NotCodable {
            let x = 1
        }
        
        let array = [1, 2, 3, 4]
        let dict = ["hello": true, "goodbye": false]
        let notCodable = NotCodable()
        
        var json: JSON? = nil
        
        // does a simple add to array work?
        json = try? JSON(array)
        XCTAssertNotNil(json)
        do {
            json = try json?.add(value: 5)
            let v = json?[4]
            XCTAssertNotNil(v)
            XCTAssertTrue(v?.intValue == 5)
            XCTAssertThrowsError(try json?.add(value:notCodable))
        } catch {
            XCTFail()
        }
        
        // does a simple add key/value work?
        json = try? JSON(dict)
        XCTAssertNotNil(json)
        do {
            json = try json?.add(value: true, forKey: "howdy")
            let v = json?["howdy"]
            XCTAssertNotNil(v)
            XCTAssertTrue(v?.boolValue == true)
            XCTAssertThrowsError(try json?.add(value:notCodable, forKey:"issaFail"))
        } catch {
            XCTFail()
        }
        
        // try to remove a key
        json = try? JSON(dict)
        XCTAssertNotNil(json)
        do {
            json = try json?.remove(key: "goodbye")
            XCTAssertNotNil(json)
            XCTAssertNil(json?["goodbye"])
        } catch {
            XCTFail()
        }
        
        // Merchant: if we add/remove, do we not bleed?!
        json = try? JSON(true)
        XCTAssertNotNil(json)
        // it's not a JSON array, throw
        XCTAssertThrowsError(try json?.add(value: 1))
        // it's not a JSON object, throw
        XCTAssertThrowsError(try json?.add(value: 1, forKey: "shakespeare"))
        // it's not a JSON object, throw
        XCTAssertThrowsError(try json?.remove(key: "merchant"))
    }
    
    func testJSONNaNZero() throws {
        struct TestStruct: Codable {
            let str: String
            let decimal: Double
            let nando: Double
        }
        let nan = NSNumber.FloatLiteralType(nan: 1, signaling: true)
        
        JSON.jsonNonConformingNumberStrategy = .zero
        
        do {
            let o = try JSON(nan)
            XCTAssertNotNil(o)
        } catch {
            print(error)
            XCTFail()
        }
        
        let test = TestStruct(
            str: "hello",
            decimal: 333.9999,
            nando: nan
        )
        
        do {
            let o = try JSON(with: test)
            XCTAssertNotNil(o)
            
            let t: TestStruct? = o.codableValue()
            XCTAssertNotNil(t)
            XCTAssertTrue(t!.nando == 0)
        } catch {
            print(error)
            XCTFail()
        }
    }
    
    func testJSONNaNNull() throws {
        struct TestStruct: Codable {
            let str: String
            let decimal: Double
            let nando: Double?
        }
        let nan = NSNumber.FloatLiteralType(nan: 1, signaling: true)
        
        JSON.jsonNonConformingNumberStrategy = .null
        
        do {
            let o = try JSON(nan)
            XCTAssertNotNil(o)
        } catch {
            print(error)
            XCTFail()
        }
        
        let test = TestStruct(
            str: "hello",
            decimal: 333.9999,
            nando: nan
        )
        
        do {
            let o = try JSON(with: test)
            XCTAssertNotNil(o)
            
            let t: TestStruct? = o.codableValue()
            XCTAssertNotNil(t)
            XCTAssertNil(t!.nando)
        } catch {
            print(error)
            XCTFail()
        }
    }
    
    func testJSONCodableDict() throws {
        enum StringEnum: String, Codable {
            case test1
            case test2
            case test3
        }
        
        enum IntEnum: Int, Codable {
            case test1
            case test2
            case test3
        }
        
        struct SubStruct: Codable {
            var x: Int = 23
        }
        
        struct CodableStruct: Codable {
            var a: Int = 47
            var b: String = "hello"
            var c: SubStruct = SubStruct()
        }
        
        let dict: [String: Any] = [
            "uuid": UUID(),
            "strEnum": StringEnum.test2,
            "intEnum": IntEnum.test2,
            "struct": CodableStruct()
        ]
        
        do {
            let json = try JSON(dict)
            print(json.prettyPrint())
            
            let strEnum: String? = json[keyPath: "strEnum"]
            XCTAssertEqual(strEnum, "test2")
            
            let intEnum: Int? = json[keyPath: "intEnum"]
            XCTAssertEqual(intEnum, 1)
            
            let b: String? = json[keyPath: "struct.b"]
            XCTAssertEqual(b, "hello")
            
            let x: Int? = json[keyPath: "struct.c.x"]
            XCTAssertEqual(x, 23)
            
            let uuid: String? = json[keyPath: "uuid"]
            XCTAssertEqual(uuid!.count, 36)
            
        } catch {
            print(error)
            XCTFail()
        }
    }
}
