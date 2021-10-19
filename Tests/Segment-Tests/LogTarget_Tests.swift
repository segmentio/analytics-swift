//
//  LogTarget_Tests.swift
//  Segment-Tests
//
//  Created by Cody Garvin on 10/18/21.
//

import Foundation
import XCTest
@testable import Segment

final class LogTarget_Tests: XCTestCase {
    
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

    func testMetric() {
               
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
                
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            XCTAssertEqual(message.message, "Metric of 5", "Message name not correctly passed")
            XCTAssertEqual(message.title, "Counter", "Type of metricnot correctly passed")
        }
        
        // Act
        analytics?.metric(MetricType.fromString("Counter"), name: "Metric of 5", value: 5, tags: ["Test"])
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHistory() {
               
        // Arrange
        let expectation = XCTestExpectation(description: "Called")
                
        // Assert
        mockLogger.logClosure = { (kind, message) in
            expectation.fulfill()
            XCTAssertEqual(message.function, "testHistory()", "Message function not correctly passed")
            XCTAssertEqual(message.logType, .history, "Type of message not correctly passed")
        }
        
        // Act
        analytics?.history(event: TrackEvent(event: "Tester", properties: nil), sender: self)
        wait(for: [expectation], timeout: 1.0)
    }

    func testLoggingDisabled() {
        
        struct LogConsoleTarget: LogTarget {
            var successClosure: ((String) -> Void)
            
            func parseLog(_ log: LogMessage) {
                XCTFail("Log should not be called when logging is disabled")
            }
        }
        
        // Arrange
        SegmentLog.loggingEnabled = false
        let logConsoleTarget = LogConsoleTarget(successClosure: { (logMessage: String) in
            // Assert
            XCTFail("This should not be called")
        })
        let loggingType = LoggingType.log
        analytics?.add(target: logConsoleTarget, type: loggingType)
        
        // Act
        analytics?.log(message: "Should hit our proper target")
    }

    func testMetricDisabled() {
        
        struct LogConsoleTarget: LogTarget {
            var successClosure: ((String) -> Void)
            
            func parseLog(_ log: LogMessage) {
                XCTFail("Log should not be called when logging is disabled")
            }
        }
        
        // Arrange
        SegmentLog.loggingEnabled = false
        let logConsoleTarget = LogConsoleTarget(successClosure: { (logMessage: String) in
            // Assert
            XCTFail("This should not be called")
        })
        let loggingType = LoggingType.log
        analytics?.add(target: logConsoleTarget, type: loggingType)
        
        // Act
        analytics?.metric(MetricType.fromString("Counter"), name: "Metric of 5", value: 5, tags: ["Test"])
    }
    
    func testHistoryDisabled() {
        
        struct LogConsoleTarget: LogTarget {
            var successClosure: ((String) -> Void)
            
            func parseLog(_ log: LogMessage) {
                XCTFail("Log should not be called when logging is disabled")
            }
        }
        
        // Arrange
        SegmentLog.loggingEnabled = false
        let logConsoleTarget = LogConsoleTarget(successClosure: { (logMessage: String) in
            // Assert
            XCTFail("This should not be called")
        })
        let loggingType = LoggingType.log
        analytics?.add(target: logConsoleTarget, type: loggingType)
        
        // Act
        analytics?.history(event: TrackEvent(event: "Tester", properties: nil), sender: self)
    }


}

