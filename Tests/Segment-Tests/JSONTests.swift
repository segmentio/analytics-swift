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
        let object = try JSON(test)
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
    
}
