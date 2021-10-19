//
//  SegmentLog_Tests.swift
//  Segment-Tests
//
//  Created by Cody Garvin on 12/18/20.
//

import Foundation
import XCTest
@testable import Segment

final class SegmentLog_Tests: XCTestCase {
    
    var analytics: Analytics?
    let mockLogger = LoggerMockPlugin()
    
    class LoggerMockPlugin: SegmentLog {
        var logClosure: ((LogFilterKind, LogMessage) -> Void)?
        var closure: (() -> Void)?
        
        override func log(_ logMessage: LogMessage, destination: LoggingType.LogDestination) {
            super.log(logMessage, destination: destination)
            logClosure?(logMessage.kind, logMessage)
        }
        
        override func flush() {
            super.flush()
            closure?()
        }
    }
    
    override func setUp() {
        analytics = Analytics(configuration: Configuration(writeKey: "test"))
        analytics?.add(plugin: mockLogger)
    }
    
    override func tearDown() {
        analytics = nil
        SegmentLog.loggingEnabled = true
    }

    func testLogging() {
                
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            
            XCTAssertEqual(kind, .debug, "Type not correctly passed")
            XCTAssertEqual(message.message, "Something Other Than Awesome", "Message not correctly passed")
        }
        
        // Act
        analytics?.log(message: "Something Other Than Awesome")
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testWarningLogging() {
                
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            XCTAssertEqual(kind, .warning, "Type not correctly passed")
        }
        
        // Act
        analytics?.log(message: "Something Other Than Awesome", kind: .warning)
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testErrorLogging() {
                
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            
            XCTAssertEqual(kind, .error, "Type not correctly passed")
        }
        
        // Act
        analytics?.log(message: "Something Other Than Awesome", kind: .error)
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateSettingsFalse() {
        var settings = Settings(writeKey: "123456789")
        settings.plan = try? JSON(["logging_enabled": false])
        mockLogger.update(settings: settings)
        
        XCTAssertFalse(SegmentLog.loggingEnabled, "Enabled logging was not set correctly")
    }
    
    func testUpdateSettingsTrue() {
        
        SegmentLog.loggingEnabled = false
        var settings = Settings(writeKey: "123456789")
        settings.plan = try? JSON(["logging_enabled": true])
        mockLogger.update(settings: settings)
        
        XCTAssertTrue(SegmentLog.loggingEnabled, "Enabled logging was not set correctly")
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
        analytics?.add(target: logConsoleTarget, type: loggingType)
        
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
        analytics?.add(target: logConsoleTarget, type: loggingType)
        
        // Act
        analytics?.log(message: "Should hit our proper target")
    }
        
    func testFlush() {
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        struct LogConsoleTarget: LogTarget {
            var successClosure: ((String) -> Void)
            
            func parseLog(_ log: LogMessage) {
                XCTFail("Log should not be called when logging is disabled")
            }
        }
        
        // Arrange
        mockLogger.closure = {
            expectation.fulfill()
        }
        
        // Act
        analytics?.flush()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLogFlush() {
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        struct LogConsoleTarget: LogTarget {
            var successClosure: ((String) -> Void)
            
            func parseLog(_ log: LogMessage) {
                XCTFail("Log should not be called when logging is disabled")
            }
        }
        
        // Arrange
        mockLogger.closure = {
            expectation.fulfill()
        }
        
        // Act
        analytics?.logFlush()
        
        wait(for: [expectation], timeout: 1.0)
    }

    
    func testInternalLog() {
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
        
        
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            XCTAssertEqual(kind, .warning, "Type not correctly passed")
        }
        
        // Act
        Analytics.segmentLog(message: "Should hit our proper target", kind: .warning)
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testInternalMetricCounter() {
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
                
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            XCTAssertEqual(message.message, "Metric of 5", "Message name not correctly passed")
            XCTAssertEqual(message.title, "Counter", "Type of metric not correctly passed")
        }
        
        // Act
        Analytics.segmentMetric(MetricType.fromString("Counter"), name: "Metric of 5", value: 5, tags: ["Test"])
        wait(for: [expectation], timeout: 1.0)
    }

    func testInternalMetricGauge() {
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
                
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            XCTAssertEqual(message.message, "Metric of 5", "Message name not correctly passed")
            XCTAssertEqual(message.title, "Gauge", "Type of metric not correctly passed")
        }
        
        // Act
        Analytics.segmentMetric(MetricType.fromString("Gauge"), name: "Metric of 5", value: 5, tags: ["Test"])
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAddTargetTwice() {

        // Arrange
        struct LogConsoleTarget: LogTarget {
            func parseLog(_ log: LogMessage) {}
        }
        let expectation = XCTestExpectation(description: "Called")
        mockLogger.logClosure = { (kind, logMessage) in
            XCTAssertTrue(logMessage.message.contains("Could not add target"))
            expectation.fulfill()
        }
        
        // Arrange
        SegmentLog.loggingEnabled = false
        let logConsoleTarget = LogConsoleTarget()
        let loggingType = LoggingType.log
        
        // Act
        analytics?.add(target: logConsoleTarget, type: loggingType)
        // Add a second time to get a duplicate error
        analytics?.add(target: logConsoleTarget, type: loggingType)
        
        wait(for: [expectation], timeout: 1.0)

    }

}

