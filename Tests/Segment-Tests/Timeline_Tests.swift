//
//  Timeline_Tests.swift
//  Timeline_Tests
//
//  Created by Cody Garvin on 9/16/21.
//

import XCTest
@testable import Segment

class Timeline_Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBaseEventCreation() {
        let expectation = XCTestExpectation(description: "First")
        
        let firstDestination = MyDestination {
            expectation.fulfill()
            return true
        }

        let configuration = Configuration(writeKey: "test")
        let analytics = Analytics(configuration: configuration)

        analytics.add(plugin: firstDestination)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "Booya")

        wait(for: [expectation], timeout: 1.0)
    }

    func testTwoBaseEventCreation() {
        let expectation = XCTestExpectation(description: "First")
        let expectationTrack2 = XCTestExpectation(description: "Second")

        let firstDestination = MyDestination {
            expectation.fulfill()
            return true
        }
        let secondDestination = MyDestination {
            expectationTrack2.fulfill()
            return true
        }

        
        // Do this to force enable the destination
        var settings = Settings(writeKey: "test")
        if let existing = settings.integrations?.dictionaryValue {
            var newIntegrations = existing
            newIntegrations[firstDestination.key] = true
            newIntegrations[secondDestination.key] = true
            settings.integrations = try! JSON(newIntegrations)
        }
        let configuration = Configuration(writeKey: "test")
        configuration.defaultSettings(settings)
        let analytics = Analytics(configuration: configuration)

        analytics.add(plugin: firstDestination)
        analytics.add(plugin: secondDestination)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "Booya")

        wait(for: [expectation, expectationTrack2], timeout: 1.0)
    }
    
    func testTwoBaseEventCreationFirstFail() {
        let expectation = XCTestExpectation(description: "First")
        let expectationTrack2 = XCTestExpectation(description: "Second")

        let firstDestination = MyDestination {
            expectation.fulfill()
            return false
        }
        let secondDestination = MyDestination {
            expectationTrack2.fulfill()
            return true
        }

        
        // Do this to force enable the destination
        var settings = Settings(writeKey: "test")
        if let existing = settings.integrations?.dictionaryValue {
            var newIntegrations = existing
            newIntegrations[firstDestination.key] = true
            newIntegrations[secondDestination.key] = true
            settings.integrations = try! JSON(newIntegrations)
        }
        let configuration = Configuration(writeKey: "test")
        configuration.defaultSettings(settings)
        let analytics = Analytics(configuration: configuration)

        analytics.add(plugin: firstDestination)
        analytics.add(plugin: secondDestination)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "Booya")

        wait(for: [expectation, expectationTrack2], timeout: 1.0)
    }

}
