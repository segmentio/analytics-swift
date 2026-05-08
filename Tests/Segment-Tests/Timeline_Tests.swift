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

        let configuration = Configuration(writeKey: uniqueWriteKey())
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
        let writeKey1 = uniqueWriteKey()
        var settings = Settings(writeKey: writeKey1)
        if let existing = settings.integrations?.dictionaryValue {
            var newIntegrations = existing
            newIntegrations[firstDestination.key] = true
            newIntegrations[secondDestination.key] = true
            settings.integrations = try! JSON(newIntegrations)
        }
        let configuration = Configuration(writeKey: writeKey1)
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
        let writeKey2 = uniqueWriteKey()
        var settings = Settings(writeKey: writeKey2)
        if let existing = settings.integrations?.dictionaryValue {
            var newIntegrations = existing
            newIntegrations[firstDestination.key] = true
            newIntegrations[secondDestination.key] = true
            settings.integrations = try! JSON(newIntegrations)
        }
        let configuration = Configuration(writeKey: writeKey2)
        configuration.defaultSettings(settings)
        let analytics = Analytics(configuration: configuration)

        analytics.add(plugin: firstDestination)
        analytics.add(plugin: secondDestination)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "Booya")

        wait(for: [expectation, expectationTrack2], timeout: 1.0)
    }

    // Regression guard for the Mediator plugin-array thread-safety fix.
    // Without a lock on Mediator.plugins, two writers adding plugins while
    // a third thread iterates the array for event execution triggers a
    // copy-on-write reallocation that releases storage the iterator still
    // holds, producing _swift_release_dealloc / EXC_BAD_ACCESS in release
    // builds.
    //
    // Exercises the Mediator directly to isolate the race from the rest of
    // the pipeline and keep the test fast.
    func testConcurrentPluginMutationAndExecute() {
        let mediator = Mediator()
        let writes = 500
        let reads = 1_000
        let done = expectation(description: "concurrent workers complete")
        done.expectedFulfillmentCount = 3

        let dummyEvent = TrackEvent(event: "stress", properties: nil)

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<writes {
                mediator.add(plugin: GooberPlugin())
            }
            done.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<writes {
                mediator.add(plugin: ZiggyPlugin())
            }
            done.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<reads {
                _ = mediator.execute(event: dummyEvent)
            }
            done.fulfill()
        }

        wait(for: [done], timeout: 10.0)
    }

    // Exercises every Mediator entry point directly on a single thread to
    // ensure the locked critical sections (including remove) and the
    // snapshot getter are covered. Complements testConcurrentPluginMutationAndExecute
    // which focuses on the concurrency guarantee rather than line coverage.
    func testMediatorAddRemoveExecuteSingleThread() {
        let mediator = Mediator()
        let dummyEvent = TrackEvent(event: "coverage", properties: nil)

        let goober = GooberPlugin()
        let ziggy = ZiggyPlugin()

        mediator.add(plugin: goober)
        mediator.add(plugin: ziggy)

        // Snapshot getter
        XCTAssertEqual(mediator.plugins.count, 2)

        // execute iterates the snapshot
        _ = mediator.execute(event: dummyEvent)

        // remove should drop exactly the matching instance
        mediator.remove(plugin: goober)
        XCTAssertEqual(mediator.plugins.count, 1)
        XCTAssertTrue(mediator.plugins.first === ziggy)

        // removing an instance that isn't in the mediator is a no-op
        mediator.remove(plugin: GooberPlugin())
        XCTAssertEqual(mediator.plugins.count, 1)

        mediator.remove(plugin: ziggy)
        XCTAssertTrue(mediator.plugins.isEmpty)
    }

}
