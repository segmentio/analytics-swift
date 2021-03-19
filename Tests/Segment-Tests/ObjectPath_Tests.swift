//
//  ObjectPath_Tests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 3/19/21.
//

import XCTest
import Segment

class ObjectPath_Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPathGet() throws {
        var dict: [String: Any] = [
            "basedOn": "Donald Duck",
            "data": [
                "characters": [
                    "Scrooge McDuck": "Moneybags",
                    "Huey": "Red",
                    "Dewey": "Green",
                    "Louie": "Blue",
                    "Gyro Gearloose": "Leather",
                ],
                "places": [
                    "Duckburg": "City",
                    "Money Bin": "Full",
                ]
            ]
        ]
        
        // check a bottom level value
        let value = dict[keyPath: "data.characters.Huey"] as? String
        XCTAssertTrue(value == "Red")
        
        // check a mid level value
        let characters = dict[keyPath: "data.characters"] as? [String: Any]
        XCTAssertNotNil(characters)
        XCTAssertTrue(characters?["Huey"] as? String == "Red")
        
        // set a bottom level value
        dict[keyPath: "data.characters.Huey"] = "Purple"
        
        let newValue = dict[keyPath: "data.characters.Huey"] as? String
        XCTAssertTrue(newValue == "Purple")
        
        // create a new top level path that doesn't exist
        dict[keyPath: "booya"] = "scrumdiddly"
        let booya = dict[keyPath: "booya"] as? String
        XCTAssertTrue(booya == "scrumdiddly")
        
        // create a new nested path that doesn't exist
        dict[keyPath: "booya.shazam"] = "bad-movie"
        let shazam = dict[keyPath: "booya.shazam"] as? String
        XCTAssertTrue(shazam == "bad-movie")
    }
}
