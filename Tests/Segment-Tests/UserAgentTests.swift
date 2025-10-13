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
        let userAgent = UserAgent.value
        
        // Test that it's not empty
        XCTAssertFalse(userAgent.isEmpty, "UserAgent should not be empty")
        
        #if os(iOS)
        // Test format and expected components
        XCTAssertTrue(userAgent.contains("Mozilla/5.0"), "Should start with Mozilla/5.0")
        XCTAssertTrue(userAgent.contains("iPhone") || userAgent.contains("iPad"), "Should contain device type")
        XCTAssertTrue(userAgent.contains("CPU"), "Should contain CPU")
        XCTAssertTrue(userAgent.contains("like Mac OS X"), "Should contain Mac OS X reference")
        XCTAssertTrue(userAgent.contains("AppleWebKit/605.1.15"), "Should contain WebKit version")
        XCTAssertTrue(userAgent.contains("Mobile/15E148"), "Should contain Mobile identifier")
        
        // Test that OS version is present and formatted correctly (e.g., "26_1" or "26_1_0")
        let osVersionRegex = try NSRegularExpression(pattern: "OS \\d+_\\d+(_\\d+)?", options: [])
        let range = NSRange(userAgent.startIndex..., in: userAgent)
        XCTAssertNotNil(osVersionRegex.firstMatch(in: userAgent, range: range), "Should contain properly formatted OS version")
        
        #elseif os(macOS)
        XCTAssertTrue(userAgent.contains("Macintosh"), "Should contain Macintosh")
        XCTAssertTrue(userAgent.contains("Mac OS X 10_15_7"), "Should contain hardcoded macOS version")
        
        #elseif os(visionOS)
        XCTAssertTrue(userAgent.contains("iPad"), "visionOS should report as iPad")
        XCTAssertTrue(userAgent.contains("CPU OS"), "Should contain CPU OS")
        
        #endif
        
        print("Generated UserAgent: \(userAgent)")
    }

    func testUserAgentWithCustomAppName() throws {
        let customUA = UserAgent.value(applicationName: "MyApp/1.0")
        XCTAssertTrue(customUA.contains("MyApp/1.0"), "Should contain custom app name")
    }

    func testUserAgentCaching() throws {
        let ua1 = UserAgent.value
        let ua2 = UserAgent.value
        XCTAssertEqual(ua1, ua2, "UserAgent should be cached and return same value")
    }


}
