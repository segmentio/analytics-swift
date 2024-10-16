//
//  UserAgentTests.swift
//  
//
//  Created by Brandon Sneed on 5/6/24.
//

import XCTest
#if canImport(WebKit)
import WebKit
#endif
@testable import Segment

final class UserAgentTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testUserAgent() throws {
        #if canImport(WebKit)
        let wkUserAgent = WKWebView().value(forKey: "userAgent") as! String
        #else
        let wkUserAgent = "unknown"
        #endif
        let userAgent = UserAgent.value
        XCTAssertEqual(wkUserAgent, userAgent, "UserAgent's don't match! system: \(wkUserAgent), generated: \(userAgent)")
    }

}
