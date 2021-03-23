//
//  KeyPath_Tests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 3/19/21.
//

import XCTest
import Segment

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
    
    func testIfExistsThenElse() {
        let mapping = [
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
            ]
        ]
        
        let event1: [String: Any] = [
            "userId": "brandon",
            "context": [
                "device": [
                    "id": "ABCDEF"
                ]
            ],
            "traits": [
                "hoot": "nanny",
                "scribble": "licious"
            ],
            "anonymousId": "123456"
        ]
        
        var dict = [String: Any]()
        let keys = mapping.keys
        for key in keys {
            dict[key] = mapping[keyPath: KeyPath(key), reference: event1]
        }
        let json = try? JSON(dict)
        print(json.prettyPrint())
        
        XCTAssertTrue(dict["device_id"] as? String == "ABCDEF")
        XCTAssertTrue(dict["user_id"] as? String == "brandon")
    }
    
    func testKeyPathSpeed() {
        let dict = baseDictionary
        measure {
            for _ in 0..<100 {
                let gyro = dict[keyPath: "data.characters.Gyro"] as? String
                XCTAssertTrue(gyro == "Leather")
            }
        }
    }
    
    func testValueForKeyPathSpeed() {
        let dict = baseDictionary
        measure {
            for _ in 0..<100 {
                let gyro = (dict as NSDictionary).value(forKeyPath: "data.characters.Gyro") as? String
                XCTAssertTrue(gyro == "Leather")
            }
        }
    }
}
