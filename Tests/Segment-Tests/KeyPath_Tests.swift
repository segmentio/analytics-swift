//
//  KeyPath_Tests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 3/19/21.
//

import XCTest
@testable import Segment

class KeyPath_Tests: XCTestCase {
    let baseDictionary: [String: Any] = [
        "basedOn": "Donald Duck",
        "data": [
            "characters": [
                "Scrooge McDuck": "Moneybags",
                "Huey": "Red",
                "Dewey": "Green",
                "Louie": "Blue",
                "Gyro": "Leather",
            ],
            "places": [
                "Duckburg": "City",
                "Money Bin": "Full",
            ]
        ]
    ]
    
    let mapping: [String: Any] = [
        "user_id":[
           "@path":"$.userId"
        ],
        "device_id":[
           "@if":[
              "exists":[
                 "@path":"$.context.device.id"
              ],
              "then":[
                 "@path":"$.context.device.id"
              ],
              "else":[
                 "@path":"$.anonymousId"
              ]
           ]
        ],
        "user_properties":[
           "@path":"$.traits"
        ],
        "blank_yes": [
            "@if": [
                "blank": "",
                "then": "yep",
                "else": "nope"
            ]
        ],
        "blank_no": [
            "@if": [
                "blank": [
                    "@path": "$.context.device.id"
                ],
                "then": "yep",
                "else": [
                    "@path": "$.context.device.id"
                ]
            ] as [String : Any]
        ]

    ]

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testKeyPathBasics() throws {
        var dict = baseDictionary
        
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
        dict[keyPath: "booya.skibbidy.shazam"] = "bad-movie"
        let shazam = dict[keyPath: "booya.skibbidy.shazam"] as? String
        XCTAssertTrue(shazam == "bad-movie")
    }

    func testNilHandling() throws {
        var dict = baseDictionary
        
        // test that nil removes a deep object
        dict[keyPath: "data.characters.Gyro"] = nil
        let shouldBeNil = dict[keyPath: "data.characters.Gyro"]
        XCTAssertNil(shouldBeNil)
        
        // test that nil removes a higher level object
        dict[keyPath: "data.characters"] = nil
        let shouldAlsoBeNil = dict[keyPath: "booya.characters"]
        XCTAssertNil(shouldAlsoBeNil)
    }

    func testIfExistsThenElseHandler() {
        var dict = [String: Any]()
        let keys = mapping.keys

        // test results when context.device.id exists
        let event1: [String: Any] = [
            "context": [
                "device": [
                    "id": "ABCDEF"
                ]
            ],
            "anonymousId": "123456"
        ]
        for key in keys {
            dict[key] = mapping[keyPath: KeyPath(key), reference: event1]
        }
        XCTAssertTrue(dict["device_id"] as? String == "ABCDEF")
        
        // test results when context.device.id does not exist
        let event2: [String: Any] = [
            "userId": "brandon",
            "traits": [
                "hoot": "nanny",
                "scribble": "licious"
            ],
            "anonymousId": "123456"
        ]
        dict = [String: Any]()
        for key in keys {
            dict[key] = mapping[keyPath: KeyPath(key), reference: event2]
        }
        XCTAssertTrue(dict["device_id"] as? String == "123456")
    }

    func testIfBlankThenElseHandler() {
        var dict = [String: Any]()
        let keys = mapping.keys

        // test results when context.device.id exists
        let event1: [String: Any] = [
            "context": [
                "device": [
                    "id": "ABCDEF"
                ]
            ],
            "anonymousId": "123456"
        ]
        for key in keys {
            dict[key] = mapping[keyPath: KeyPath(key), reference: event1]
        }
        XCTAssertTrue(dict["blank_no"] as? String == "ABCDEF")
        
        // test results when context.device.id does not exist
        let event2: [String: Any] = [
            "anonymousId": "123456"
        ]
        dict = [String: Any]()
        for key in keys {
            dict[key] = mapping[keyPath: KeyPath(key), reference: event2]
        }
        XCTAssertTrue(dict["blank_yes"] as? String == "yep")
    }

    func testPathHandler() {
        var dict = [String: Any]()
        let keys = mapping.keys

        // test results when context.device.id exists
        let event1: [String: Any] = [
            "userId": "brandon",
            "traits": [
                "hoot": "nanny",
                "scribble": "licious"
            ]
        ]
        for key in keys {
            dict[key] = mapping[keyPath: KeyPath(key), reference: event1]
        }
        let traits = dict["user_properties"] as? [String: Any]
        XCTAssertTrue(traits?["hoot"] as? String == "nanny")
        XCTAssertTrue(traits?["scribble"] as? String == "licious")
        XCTAssertTrue(dict["user_id"] as? String == "brandon")
    }
    
    // useful for once-in-awhile checking, but doesn't need to be run as part of
    // the overall test suite.
    /*func testDictDeconstructionSpeed() {
        let dict = baseDictionary
        // test regular dictionary crap
        measure {
            for _ in 0..<100 {
                let data = dict["data"] as? [String: Any]
                let characters = data?["characters"] as? [String: Any]
                let gyro = characters?["Gyro"] as? String
                XCTAssertTrue(gyro == "Leather")
            }
        }
    }
    
    func testKeyPathSpeed() {
        let dict = baseDictionary
        // test keypath stuff
        measure {
            for _ in 0..<100 {
                let gyro = dict[keyPath: "data.characters.Gyro"] as? String
                XCTAssertTrue(gyro == "Leather")
            }
        }
    }

    func testJSONKeyPathSpeed() throws {
        let dict = baseDictionary
        let json = try JSON(dict)
        // test json keypath stuff
        measure {
            for _ in 0..<100 {
                let gyro: String? = json[keyPath: "data.characters.Gyro"]
                XCTAssertTrue(gyro == "Leather")
            }
        }
    }*/

}
