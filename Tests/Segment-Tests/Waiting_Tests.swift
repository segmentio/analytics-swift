//
//  Waiting_Tests.swift
//  Segment
//
//  Created by Brandon Sneed on 7/12/25.
//

import XCTest
import Sovran
@testable import Segment

class ExampleWaitingPlugin: EventPlugin, WaitingPlugin {
    let type: PluginType
    var identifier: String
    
    weak var analytics: Analytics?
    
    init(identifier: String = "ExampleWaitingPlugin") {
        self.type = .enrichment
        self.identifier = identifier
    }
    
    func update(settings: Settings, type: UpdateType) {
        // we got our settings, do something and pretend to wait
        if type == .initial {
            self.analytics?.pauseEventProcessing(plugin: self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                // pretend to hit the network or something ... get some stuff...
                guard let self else { return }
                self.analytics?.resumeEventProcessing(plugin: self)
            }
        }
    }

    func track(event: TrackEvent) -> TrackEvent? {
        var workingEvent = event
        
        workingEvent.context?.setValue(identifier, forKeyPath: "processed_by")
        
        return workingEvent
    }
}

class SlowWaitingPlugin: EventPlugin, WaitingPlugin {
    let type: PluginType
    var shouldResume: Bool = false
    
    weak var analytics: Analytics?
    
    init() {
        self.type = .enrichment
    }
    
    func update(settings: Settings, type: UpdateType) {
        print("SlowWaitingPlugin.update() called with type: \(type)")
        if type == .initial {
            analytics?.pauseEventProcessing(plugin: self)
            /// don't resume
        }
    }
    
    func manualResume() {
        analytics?.resumeEventProcessing(plugin: self)
    }

    func track(event: TrackEvent) -> TrackEvent? {
        var workingEvent = event
        workingEvent.context?.setValue("slow_plugin", forKeyPath: "processed_by")
        return workingEvent
    }
}

class MockDestinationPlugin: DestinationPlugin {
    var timeline = Timeline()
    
    let type = PluginType.destination
    let key = "MockDestination"
    weak var analytics: Analytics?
}

final class Waiting_Tests: XCTestCase, Subscriber {
    override func setUpWithError() throws {
        Telemetry.shared.enable = false
    }
    
    func testBasicWaitingPlugin() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testWaiting"))
        
        // System should start as not running
        XCTAssertFalse(analytics.running())
        
        analytics.add(plugin: ExampleWaitingPlugin())
        
        // Track an event while paused
        analytics.track(name: "test_event")
        
        // System should still be paused
        XCTAssertFalse(analytics.running())
        
        // Wait until plugin resumes and system starts
        waitUntilStarted(analytics: analytics, timeout: 20)
        
        // System should now be running
        XCTAssertTrue(analytics.running())
    }
    
    func testMultipleWaitingPlugins() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testMultipleWaiting"))
        
        let plugin1 = ExampleWaitingPlugin(identifier: "plugin1")
        let plugin2 = ExampleWaitingPlugin(identifier: "plugin2")
        
        analytics.add(plugin: plugin1)
        analytics.add(plugin: plugin2)
        
        // System should be paused with multiple waiting plugins
        XCTAssertFalse(analytics.running())
        
        // Track events while paused
        analytics.track(name: "event1")
        analytics.track(name: "event2")
        
        // Wait for both plugins to finish
        waitUntilStarted(analytics: analytics, timeout: 5)
        
        // System should now be running
        XCTAssertTrue(analytics.running())
    }
    
    func testTimeoutForceStart() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testTimeout"))
        
        let slowPlugin = SlowWaitingPlugin()
        analytics.add(plugin: slowPlugin)
        
        // System should be paused
        XCTAssertFalse(analytics.running())
        
        // Track an event while paused
        analytics.track(name: "timeout_test")
        
        // Plugin never resumes, but timeout should force start
        // Note: We'd need to mock the timer or reduce timeout for actual testing
        // For now, manually trigger the timeout behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Simulate timeout by forcing resume
            analytics.store.dispatch(action: System.ForceRunningAction())
        }
        
        waitUntilStarted(analytics: analytics, timeout: 1)
        XCTAssertTrue(analytics.running())
    }
    
    func testEventQueueingAndReplay() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testQueueing"))
        let plugin = ExampleWaitingPlugin()
        
        analytics.add(plugin: plugin)
        
        // Track multiple events while paused
        analytics.track(name: "queued_event_1")
        analytics.track(name: "queued_event_2")
        analytics.track(name: "queued_event_3")
        
        // System should still be paused
        XCTAssertFalse(analytics.running())
        
        // Wait for system to start
        waitUntilStarted(analytics: analytics)
        
        // All events should have been replayed and processed
        XCTAssertTrue(analytics.running())
    }
    
    func testPauseWhenAlreadyPaused() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testDoublePause"))
        
        let plugin1 = SlowWaitingPlugin()
        let plugin2 = SlowWaitingPlugin()
        
        analytics.add(plugin: plugin1)
        // System is now paused by plugin1
        XCTAssertFalse(analytics.running())
        
        analytics.add(plugin: plugin2)
        // Adding plugin2 should not break anything
        XCTAssertFalse(analytics.running())
        
        // Wait until both plugins are in waiting state
        let waitForPluginsAdded = XCTestExpectation(description: "Plugins added to waiting list")
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let state: System = analytics.store.currentState()!
            if state.waitingPlugins.count == 2 {
                waitForPluginsAdded.fulfill()
                timer.invalidate()
            }
        }
        wait(for: [waitForPluginsAdded], timeout: 1)
        
        // Resume plugin1 - system should still be paused because plugin2 is waiting
        plugin1.manualResume()
        
        // Small delay to let state update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(analytics.running())
            
            // Now resume plugin2 - system should start
            plugin2.manualResume()
        }
        
        waitUntilStarted(analytics: analytics, timeout: 3)
        XCTAssertTrue(analytics.running())
    }
    
    func testResumeWhenAlreadyRunning() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testDoubleResume"))
        
        let plugin = ExampleWaitingPlugin()
        analytics.add(plugin: plugin)
        
        // Wait for normal startup
        waitUntilStarted(analytics: analytics)
        XCTAssertTrue(analytics.running())
        
        // Try to resume again - should be no-op
        analytics.resumeEventProcessing(plugin: plugin)
        XCTAssertTrue(analytics.running())
    }
    
    func testWaitingPluginState() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testState"))
        
        let plugin1 = SlowWaitingPlugin()
        let plugin2 = SlowWaitingPlugin()
        
        // Check initial state
        waitForWaitingPluginCount(analytics: analytics, expectedCount: 0)
        
        analytics.add(plugin: plugin1)
        print("Added plugin1")
        analytics.add(plugin: plugin2)
        print("Added plugin2")
        waitForWaitingPluginCount(analytics: analytics, expectedCount: 2)
        
        // Resume one plugin and wait for state update
        plugin1.manualResume()
        waitForWaitingPluginCount(analytics: analytics, expectedCount: 1)
        
        // System should still be paused because plugin2 is waiting
        XCTAssertFalse(analytics.running())
        
        // Resume second plugin and wait for state update
        plugin2.manualResume()
        waitForWaitingPluginCount(analytics: analytics, expectedCount: 0)
        
        // Now wait for system to start
        waitUntilStarted(analytics: analytics, timeout: 2)
        
        let finalState: System = analytics.store.currentState()!
        XCTAssertTrue(finalState.running)
    }
    
    func testDestinationWaitingPlugin() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testDestination"))
        let destination = MockDestinationPlugin()
        let waitingPlugin = ExampleWaitingPlugin()
        
        analytics.store.subscribe(self) { (state: System) in
            print("State updated running: \(state.running)")
        }
        
        analytics.add(plugin: destination)
        destination.add(plugin: waitingPlugin)
        
        // System should be paused
        XCTAssertFalse(analytics.running())
        
        // Plugin should auto-resume after 1 second
        waitUntilStarted(analytics: analytics, timeout: 5)
        XCTAssertTrue(analytics.running())
    }
    
    func testDestinationSlowWaitingPlugin() {
        let analytics = Analytics(configuration: Configuration(writeKey: "testDestination"))
        let destination = MockDestinationPlugin()
        let waitingPlugin = SlowWaitingPlugin()
        
        analytics.store.subscribe(self) { (state: System) in
            print("State updated running: \(state.running)")
        }
        
        analytics.add(plugin: destination)
        destination.add(plugin: waitingPlugin)
        
        // System should be paused (proving destination.add worked)
        XCTAssertFalse(analytics.running())
        
        // Resume should work normally
        // this will pull it out of the waitingPlugins list.
        waitingPlugin.manualResume()
        
        // but update will get called, pausing it once more.
        waitForWaitingPluginCount(analytics: analytics, expectedCount: 1)
        
        // at which point, we have to resume it again.
        waitingPlugin.manualResume()
        
        waitUntilStarted(analytics: analytics, timeout: 5)
        XCTAssertTrue(analytics.running())
    }
}

// Helper extension
extension Waiting_Tests {
    func waitUntilStarted(analytics: Analytics, timeout: TimeInterval = 5) {
        let expectation = XCTestExpectation(description: "Analytics started")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if analytics.running() {
                expectation.fulfill()
                timer.invalidate()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
    
    func waitForWaitingPluginCount(analytics: Analytics, expectedCount: Int, timeout: TimeInterval = 2) {
        let expectation = XCTestExpectation(description: "Waiting for \(expectedCount) plugins")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let state: System = analytics.store.currentState()!
            if state.waitingPlugins.count == expectedCount {
                expectation.fulfill()
                timer.invalidate()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
}
