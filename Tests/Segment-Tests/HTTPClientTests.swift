//
//  HTTPClientTests.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 1/21/21.
//

import XCTest
@testable import Segment

class HTTPClientTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let client = HTTPClient(analytics: analytics)
        
        let url = client.segmentURL(for: "blah.segment.com", path:"/booya")
        print(url)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
