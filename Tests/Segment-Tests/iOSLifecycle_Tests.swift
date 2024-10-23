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
}

#endif
