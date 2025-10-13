import XCTest
@testable import Segment

#if os(iOS) || os(tvOS) || os(visionOS)
final class iOSLifecycle_Tests: XCTestCase {
    override func setUpWithError() throws {
        Telemetry.shared.enable = false
    }

    func testInstallEventCreation() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        let iosLifecyclePlugin = iOSLifecycleEvents()
        analytics.add(plugin: iosLifecyclePlugin)
        
        waitUntilStarted(analytics: analytics)
        
        UserDefaults.standard.setValue(nil, forKey: "SEGBuildKeyV2")
        
        // This is a hack that needs to be dealt with
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        
        iosLifecyclePlugin.application(nil, didFinishLaunchingWithOptions: nil)
        
        let trackEvent: TrackEvent? = outputReader.events.first as? TrackEvent
        XCTAssertTrue(trackEvent?.event == "Application Installed")
        XCTAssertTrue(trackEvent?.type == "track")
    }

    func testInstallEventUpdated() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        let iosLifecyclePlugin = iOSLifecycleEvents()
        analytics.add(plugin: iosLifecyclePlugin)
        
        waitUntilStarted(analytics: analytics)
        
        UserDefaults.standard.setValue("1337", forKey: "SEGBuildKeyV2")
        
        // This is a hack that needs to be dealt with
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        
        iosLifecyclePlugin.application(nil, didFinishLaunchingWithOptions: nil)
        
        let trackEvent: TrackEvent? = outputReader.events.first as? TrackEvent
        XCTAssertTrue(trackEvent?.event == "Application Updated")
        XCTAssertTrue(trackEvent?.type == "track")
    }
    
    func testInstallEventOpened() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        let iosLifecyclePlugin = iOSLifecycleEvents()
        analytics.add(plugin: iosLifecyclePlugin)
        
        waitUntilStarted(analytics: analytics)
        
        iosLifecyclePlugin.application(nil, didFinishLaunchingWithOptions: nil)
                
        let trackEvent: TrackEvent? = outputReader.events.last as? TrackEvent
        XCTAssertTrue(trackEvent?.event == "Application Opened")
        XCTAssertTrue(trackEvent?.type == "track")
    }
    
    func testApplicationForegroundedOnlyFiresAfterBackground() {
            let analytics = Analytics(configuration: Configuration(writeKey: "test")
                .setTrackedApplicationLifecycleEvents(.all))
            let outputReader = OutputReaderPlugin()
            analytics.add(plugin: outputReader)
            
            waitUntilStarted(analytics: analytics)
            
            // Simulate: Background → Foreground
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            
            let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Foregrounded",
                          "Application Foregrounded should fire after coming back from background")
        }
        
        func testTransientInterruptionDoesNotFireForegrounded() {
            let analytics = Analytics(configuration: Configuration(writeKey: "test")
                .setTrackedApplicationLifecycleEvents(.all))
            let outputReader = OutputReaderPlugin()
            analytics.add(plugin: outputReader)
            
            waitUntilStarted(analytics: analytics)
            
            // Clear any startup events by capturing the current state
            let eventsBeforeInterruption = outputReader.lastEvent
            
            // Simulate: willResignActive → didBecomeActive (notification center, control center, etc.)
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            
            // lastEvent should still be the same as before (no new "Application Foregrounded")
            let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
            if trackEvent?.event == "Application Foregrounded" {
                XCTFail("Application Foregrounded should NOT fire for transient interruptions like notification center")
            }
        }
        
        func testForegroundedNotFiredWithoutPriorBackground() {
            let analytics = Analytics(configuration: Configuration(writeKey: "test")
                .setTrackedApplicationLifecycleEvents(.all))
            let outputReader = OutputReaderPlugin()
            analytics.add(plugin: outputReader)
            
            waitUntilStarted(analytics: analytics)
            
            // Simulate: willEnterForeground without prior didEnterBackground
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            
            let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
            XCTAssertNotEqual(trackEvent?.event, "Application Foregrounded",
                             "Application Foregrounded should not fire without a prior background event")
        }
        
        func testMultipleBackgroundForegroundCycles() {
            let analytics = Analytics(configuration: Configuration(writeKey: "test")
                .setTrackedApplicationLifecycleEvents(.all))
            let outputReader = OutputReaderPlugin()
            analytics.add(plugin: outputReader)
            
            waitUntilStarted(analytics: analytics)
            
            // Cycle 1: Background → Foreground
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            
            var trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Foregrounded",
                          "First foreground cycle should fire Application Foregrounded")
            
            // Cycle 2: Background → Foreground
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            
            trackEvent = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Foregrounded",
                          "Second foreground cycle should also fire Application Foregrounded")
        }
        
        func testBackgroundAlwaysFires() {
            let analytics = Analytics(configuration: Configuration(writeKey: "test")
                .setTrackedApplicationLifecycleEvents(.all))
            let outputReader = OutputReaderPlugin()
            analytics.add(plugin: outputReader)
            
            waitUntilStarted(analytics: analytics)
            
            // Simulate: Background
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            
            let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Backgrounded",
                          "Application Backgrounded should always fire when app enters background")
        }
        
        func testComplexLifecycleSequence() {
            let analytics = Analytics(configuration: Configuration(writeKey: "test")
                .setTrackedApplicationLifecycleEvents(.all))
            let outputReader = OutputReaderPlugin()
            analytics.add(plugin: outputReader)
            
            waitUntilStarted(analytics: analytics)
            
            // Simulate realistic user behavior:
            // 1. Background the app
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            var trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Backgrounded")
            
            // 2. Foreground the app
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            trackEvent = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Foregrounded")
            
            // 3. Pull down notification center (transient interruption)
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            
            // Last event should still be "Application Foregrounded" from step 2
            trackEvent = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Foregrounded",
                          "Transient interruption should not create new events")
            
            // 4. Background again
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            trackEvent = outputReader.lastEvent as? TrackEvent
            XCTAssertEqual(trackEvent?.event, "Application Backgrounded")
        }
        
        func testDidBecomeActiveDoesNotFireForegrounded() {
            let analytics = Analytics(configuration: Configuration(writeKey: "test")
                .setTrackedApplicationLifecycleEvents(.all))
            let outputReader = OutputReaderPlugin()
            analytics.add(plugin: outputReader)
            
            waitUntilStarted(analytics: analytics)
            
            // Simulate: didBecomeActive (should not fire anything anymore)
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            
            // Verify no new event was created
            let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
            if trackEvent?.event == "Application Foregrounded" {
                XCTFail("didBecomeActive should not fire Application Foregrounded anymore")
            }
        }
}

#endif
