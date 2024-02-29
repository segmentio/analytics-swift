//
//  MemoryLeak_Tests.swift
//
//
//  Created by Brandon Sneed on 10/17/22.
//

import XCTest
@testable import Segment

final class MemoryLeak_Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLeaksVerbose() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))

        waitUntilStarted(analytics: analytics)
        analytics.track(name: "test")

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))

        let segmentDest = analytics.find(pluginType: SegmentDestination.self)!
        let destMetadata = segmentDest.timeline.find(pluginType: DestinationMetadataPlugin.self)!
        let startupQueue = analytics.find(pluginType: StartupQueue.self)!

        let context = analytics.find(pluginType: Context.self)!

        #if !os(Linux) && !os(Windows)
        let deviceToken = analytics.find(pluginType: DeviceToken.self)!
        #endif
        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        let iosLifecycle = analytics.find(pluginType: iOSLifecycleEvents.self)!
        let iosMonitor = analytics.find(pluginType: iOSLifecycleMonitor.self)!
        #elseif os(watchOS)
        let watchLifecycle = analytics.find(pluginType: watchOSLifecycleEvents.self)!
        let watchMonitor = analytics.find(pluginType: watchOSLifecycleMonitor.self)!
        #elseif os(macOS)
        let macLifecycle = analytics.find(pluginType: macOSLifecycleEvents.self)!
        let macMonitor = analytics.find(pluginType: macOSLifecycleMonitor.self)!
        #endif

        // test that enrichment closure isn't leaked.  was previously a retain loop.
        analytics.add { event in
            return event
        }

        analytics.remove(plugin: startupQueue)
        analytics.remove(plugin: segmentDest)
        segmentDest.remove(plugin: destMetadata)

        analytics.remove(plugin: context)
        #if !os(Linux) && !os(Windows)
        analytics.remove(plugin: deviceToken)
        #endif
        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        analytics.remove(plugin: iosLifecycle)
        analytics.remove(plugin: iosMonitor)
        #elseif os(watchOS)
        analytics.remove(plugin: watchLifecycle)
        analytics.remove(plugin: watchMonitor)
        #elseif os(macOS)
        analytics.remove(plugin: macLifecycle)
        analytics.remove(plugin: macMonitor)
        #endif

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))

        checkIfLeaked(segmentDest)
        checkIfLeaked(destMetadata)
        checkIfLeaked(startupQueue)

        checkIfLeaked(context)
        #if !os(Linux) && !os(Windows)
        checkIfLeaked(deviceToken)
        #endif
        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        checkIfLeaked(iosLifecycle)
        checkIfLeaked(iosMonitor)
        #elseif os(watchOS)
        checkIfLeaked(watchLifecycle)
        checkIfLeaked(watchMonitor)
        #elseif os(macOS)
        checkIfLeaked(macLifecycle)
        checkIfLeaked(macMonitor)
        #endif

        checkIfLeaked(analytics)
    }

    func testLeaksSimple() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))

        waitUntilStarted(analytics: analytics)
        analytics.track(name: "test")

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))

        checkIfLeaked(analytics)
    }

}
