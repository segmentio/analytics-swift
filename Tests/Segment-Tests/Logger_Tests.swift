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
    
    var analytics: Analytics?
    let mockLogger = LoggerMockPlugin()
    
    override func setUp() {
        analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics?.add(plugin: mockLogger)
    }
    
    override func tearDown() {
        analytics = nil
    }

    class LoggerMockPlugin: Logger {
        var logClosure: ((LogFilterKind, String) -> Void)?
        var closure: (() -> Void)?
        
        override func log(_ logMessage: LogMessage, destination: LoggingType.LogDestination) {
            super.log(logMessage, destination: destination)
            logClosure?(logMessage.kind, logMessage.message)
        }
        
        override func flush() {
            super.flush()
            closure?()
        }
    }

    func testLogging() {
                
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            
            XCTAssertEqual(kind, .debug, "Type not correctly passed")
            XCTAssertEqual(message, "Something Other Than Awesome", "Message not correctly passed")
        }
        
        // Act
        analytics?.log(message: "Something Other Than Awesome")
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testTargetSuccess() {
        
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        struct LogConsoleTarget: LogTarget {
            var successClosure: ((String) -> Void)
            
            func parseLog(_ log: LogMessage) {
                print("[Segment Tests - \(log.function ?? ""):\(String(log.line ?? 0))] \(log.message)\n")
                successClosure(log.message)
            }
        }
        
        let logConsoleTarget = LogConsoleTarget(successClosure: { (logMessage: String) in
            expectation.fulfill()
        })
        let loggingType = LoggingType.log
        try? analytics?.add(target: logConsoleTarget, type: loggingType)
        
        // Act
        analytics?.log(message: "Should hit our proper target")
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testTargetFailure() {
        
        // Arrange        
        struct LogConsoleTarget: LogTarget {
            var successClosure: ((String) -> Void)
            
            func parseLog(_ log: LogMessage) {
                print("[Segment Tests - \(log.function ?? ""):\(String(log.line ?? 0))] \(log.message)\n")
                successClosure(log.message)
            }
        }
        
        let logConsoleTarget = LogConsoleTarget(successClosure: { (logMessage: String) in
            XCTFail("Should not hit this since it was registered for history")
        })
        let loggingType = LoggingType.history
        try? analytics?.add(target: logConsoleTarget, type: loggingType)
        
        // Act
        analytics?.log(message: "Should hit our proper target")
    }
}

