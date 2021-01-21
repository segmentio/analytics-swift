//
//  Logger_Tests.swift
//  Segment-Tests
//
//  Created by Cody Garvin on 12/18/20.
//

import Foundation
import XCTest
@testable import Segment

final class Logger_Tests: XCTestCase {

    class LoggerMock: Logger {
        var logClosure: ((LogType, String) -> Void)?
        var closure: (() -> Void)?
        
        override func log(type: LogType, message: String, event: RawEvent?) {
            super.log(type: type, message: message, event: event)
            logClosure?(type, message)
        }
        
        override func flush() {
            super.flush()
            closure?()
        }
    }

    func testLogging() {
        
        let analytics = Analytics(writeKey: "test").build()
        
        let expectation = XCTestExpectation(description: "Called")
        
        let mockLogger = LoggerMock(name: "Blah", analytics: analytics)
        mockLogger.logClosure = { (type, message) in
            expectation.fulfill()
            
            XCTAssertEqual(type, .info, "Type not correctly passed")
            XCTAssertEqual(message, "Something Other Than Awesome", "Message not correctly passed")
        }
        analytics.add(plugin: mockLogger)
        analytics.log(message: "Something Other Than Awesome")
        wait(for: [expectation], timeout: 1.0)
    }
}

