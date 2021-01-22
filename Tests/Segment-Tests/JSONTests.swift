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
        
        let str = typedDict?["str"]?.stringValue
        let float = typedDict?["float"]?.floatValue
        let int = typedDict?["int"]?.intValue
        let uint = typedDict?["uint"]?.uintValue
        let double = typedDict?["double"]?.doubleValue
        let decimal = typedDict?["decimal"]?.decimalValue
        let array = typedDict?["array"]?.arrayValue
        let dict = typedDict?["dict"]?.dictionaryValue
        
        XCTAssertEqual(str, "hello")
        XCTAssertEqual(float, 3.14)
        XCTAssertEqual(int, -42)
        XCTAssertEqual(uint, 42)
        XCTAssertEqual(double, 1.234)
        XCTAssertEqual(decimal, 333.9999)
        
        XCTAssertEqual(array?[0].stringValue, "1")
        XCTAssertEqual(array?[1].stringValue, "2")
        
        XCTAssertEqual(dict?["1"]?.intValue, 1)
        XCTAssertEqual(dict?["2"]?.intValue, 2)
        
        let b = typedDict?["dict"]?.dictionaryValue2
        print(b)
    }
    
}
