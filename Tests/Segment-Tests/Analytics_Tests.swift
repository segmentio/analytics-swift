import XCTest
@testable import Segment

final class Analytics_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let myDestination = MyDestination()
        myDestination.add(plugin: GooberPlugin())
        
        analytics.add(plugin: ZiggyPlugin())
        analytics.add(plugin: myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
    
    func testPluginConfigure() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let ziggy = ZiggyPlugin()
        let myDestination = MyDestination()
        let goober = GooberPlugin()
        myDestination.add(plugin: goober)

        analytics.add(plugin: ziggy)
        analytics.add(plugin: myDestination)
        
        XCTAssertNotNil(ziggy.analytics)
        XCTAssertNotNil(myDestination.analytics)
        XCTAssertNotNil(goober.analytics)
    }
    
    func testPluginRemove() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let myDestination = MyDestination()
        myDestination.add(plugin: GooberPlugin())
        
        let expectation = XCTestExpectation(description: "Ziggy Expectation")
        let ziggy = ZiggyPlugin()
        ziggy.completion = {
            expectation.fulfill()
        }
        analytics.add(plugin: ziggy)
        analytics.add(plugin: myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
        analytics.remove(plugin: ziggy)
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testDestinationEnabled() {
        // need to clear settings for this one.
        UserDefaults.standard.removePersistentDomain(forName: "com.segment.storage.test")
        
        let expectation = XCTestExpectation(description: "MyDestination Expectation")
        let myDestination = MyDestination {
            expectation.fulfill()
            return true
        }

        var settings = Settings(writeKey: "test")
        if let existing = settings.integrations?.dictionaryValue {
            var newIntegrations = existing
            newIntegrations[myDestination.key] = true
            settings.integrations = try! JSON(newIntegrations)
        }
        let configuration = Configuration(writeKey: "test")
        configuration.defaultSettings(settings)
        let analytics = Analytics(configuration: configuration)

        analytics.add(plugin: myDestination)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "testDestinationEnabled")
        
        let dest = analytics.find(key: myDestination.key)
        XCTAssertNotNil(dest)
        XCTAssertTrue(dest is MyDestination)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // Linux doesn't support XCTExpectFailure
    #if !os(Linux)
    func testDestinationNotEnabled() {
        // need to clear settings for this one.
        UserDefaults.standard.removePersistentDomain(forName: "com.segment.storage.test")
        
        let expectation = XCTestExpectation(description: "MyDestination Expectation")
        let myDestination = MyDestination(disabled: true) {
            expectation.fulfill()
            return true
        }

        let configuration = Configuration(writeKey: "test")
        let analytics = Analytics(configuration: configuration)

        analytics.add(plugin: myDestination)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "testDestinationEnabled")
        
        XCTExpectFailure {
            wait(for: [expectation], timeout: 1.0)
        }
    }
    #endif
    
    func testAnonymousId() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let anonId = analytics.anonymousId
        
        XCTAssertTrue(anonId != "")
        XCTAssertTrue(anonId.count == 36) // it's a UUID y0.
    }
    
    func testContext() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "token check")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let context = trackEvent?.context?.dictionaryValue
        // Verify that context isn't empty here.
        // We need to verify the values but will do that in separate platform specific tests.
        XCTAssertNotNil(context)
        XCTAssertNotNil(context?["screen"], "screen missing!")
        XCTAssertNotNil(context?["network"], "network missing!")
        XCTAssertNotNil(context?["os"], "os missing!")
        XCTAssertNotNil(context?["timezone"], "timezone missing!")
        XCTAssertNotNil(context?["library"], "library missing!")
        XCTAssertNotNil(context?["device"], "device missing!")

        // this key not present on watchOS (doesn't have webkit)
        #if !os(watchOS)
        XCTAssertNotNil(context?["userAgent"], "userAgent missing!")
        #endif
        
        // these keys not present on linux
        #if !os(Linux)
        XCTAssertNotNil(context?["app"], "app missing!")
        XCTAssertNotNil(context?["locale"], "locale missing!")
        #endif
    }
    
    func testDeviceToken() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

        waitUntilStarted(analytics: analytics)
        
        analytics.setDeviceToken("1234")
        analytics.track(name: "token check")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let device = trackEvent?.context?.dictionaryValue
        let token = device?[keyPath: "device.token"] as? String
        XCTAssertTrue(token == "1234")
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testDeviceTokenData() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        let dataToken = UUID().asData()
        analytics.registeredForRemoteNotifications(deviceToken: dataToken)
        analytics.track(name: "token check")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let device = trackEvent?.context?.dictionaryValue
        let token = device?[keyPath: "device.token"] as? String
        XCTAssertTrue(token?.count == 32) // it's a uuid w/o the dashes.  36 becomes 32.
    }
    #endif
    
    func testTrack() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "test track")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        XCTAssertTrue(trackEvent?.event == "test track")
        XCTAssertTrue(trackEvent?.type == "track")
    }
    
    func testIdentify() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let identifyEvent: IdentifyEvent? = outputReader.lastEvent as? IdentifyEvent
        XCTAssertTrue(identifyEvent?.userId == "brandon")
        let traits = identifyEvent?.traits?.dictionaryValue
        XCTAssertTrue(traits?["email"] as? String == "blah@blah.com")
    }

    func testUserIdAndTraitsPersistCorrectly() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let identifyEvent: IdentifyEvent? = outputReader.lastEvent as? IdentifyEvent
        XCTAssertTrue(identifyEvent?.userId == "brandon")
        let traits = identifyEvent?.traits?.dictionaryValue
        XCTAssertTrue(traits?["email"] as? String == "blah@blah.com")
        
        analytics.track(name: "test")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        XCTAssertTrue(trackEvent?.userId == "brandon")
        let trackTraits = trackEvent?.context?.dictionaryValue?["traits"] as? [String: Any]
        XCTAssertNil(trackTraits)
        
        let analyticsTraits: MyTraits? = analytics.traits()
        XCTAssertEqual("blah@blah.com", analyticsTraits?.email)
    }
    

    func testScreen() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.screen(title: "screen1", category: "category1")
        
        let screen1Event: ScreenEvent? = outputReader.lastEvent as? ScreenEvent
        XCTAssertTrue(screen1Event?.name == "screen1")
        XCTAssertTrue(screen1Event?.category == "category1")
        
        analytics.screen(title: "screen2", category: "category2", properties: MyTraits(email: "blah@blah.com"))
        
        let screen2Event: ScreenEvent? = outputReader.lastEvent as? ScreenEvent
        XCTAssertTrue(screen2Event?.name == "screen2")
        XCTAssertTrue(screen2Event?.category == "category2")
        let props = screen2Event?.properties?.dictionaryValue
        XCTAssertTrue(props?["email"] as? String == "blah@blah.com")
    }
    
    func testGroup() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.group(groupId: "1234")
        
        let group1Event: GroupEvent? = outputReader.lastEvent as? GroupEvent
        XCTAssertTrue(group1Event?.groupId == "1234")
        
        analytics.group(groupId: "4567", traits: MyTraits(email: "blah@blah.com"))
        
        let group2Event: GroupEvent? = outputReader.lastEvent as? GroupEvent
        XCTAssertTrue(group2Event?.groupId == "4567")
        let props = group2Event?.traits?.dictionaryValue
        XCTAssertTrue(props?["email"] as? String == "blah@blah.com")
    }
    
    func testReset() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let identifyEvent: IdentifyEvent? = outputReader.lastEvent as? IdentifyEvent
        XCTAssertTrue(identifyEvent?.userId == "brandon")
        let traits = identifyEvent?.traits?.dictionaryValue
        XCTAssertTrue(traits?["email"] as? String == "blah@blah.com")
        
        let currentAnonId = analytics.anonymousId
        let currentUserInfo: UserInfo? = analytics.store.currentState()

        analytics.reset()
        
        let newAnonId = analytics.anonymousId
        let newUserInfo: UserInfo? = analytics.store.currentState()
        XCTAssertNotEqual(currentAnonId, newAnonId)
        XCTAssertNotEqual(currentUserInfo?.anonymousId, newUserInfo?.anonymousId)
        XCTAssertNotEqual(currentUserInfo?.userId, newUserInfo?.userId)
        XCTAssertNotEqual(currentUserInfo?.traits, newUserInfo?.traits)
    }

    func testFlush() {
        // Use a specific writekey to this test so we do not collide with other cached items.
        let analytics = Analytics(configuration: Configuration(writeKey: "testFlush_do_not_reuse_this_writekey"))
        
        waitUntilStarted(analytics: analytics)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
    
        let currentBatchCount = analytics.storage.eventFiles(includeUnfinished: true).count
    
        analytics.flush()
        analytics.track(name: "test")
        
        let newBatchCount = analytics.storage.eventFiles(includeUnfinished: true).count
        // 1 new temp file
        XCTAssertTrue(newBatchCount == currentBatchCount + 1, "New Count (\(newBatchCount)) should be \(currentBatchCount) + 1")
    }
    
    func testVersion() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "whataversion")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let context = trackEvent?.context?.dictionaryValue
        let eventVersion = context?[keyPath: "library.version"] as? String
        let analyticsVersion = analytics.version()
        
        XCTAssertEqual(eventVersion, analyticsVersion)
    }
    
    class AnyDestination: DestinationPlugin {
        var timeline: Timeline
        let type: PluginType
        let key: String
        var analytics: Analytics?
        
        init(key: String) {
            self.key = key
            self.type = .destination
            self.timeline = Timeline()
        }
    }

    // Test to ensure bundled and unbundled integrations are populated correctly
    func testDestinationMetadata() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let mixpanel = AnyDestination(key: "Mixpanel")
        let outputReader = OutputReaderPlugin()
        
        // we want the output reader on the segment plugin
        // cuz that's the only place the metadata is getting added.
        let segmentDest = analytics.find(pluginType: SegmentDestination.self)
        segmentDest?.add(plugin: outputReader)

        analytics.add(plugin: mixpanel)
        var settings = Settings(writeKey: "123")
        let integrations = try? JSON([
            "Segment.io": JSON([
                "unbundledIntegrations":
                    [
                        "Customer.io",
                        "Mixpanel",
                        "Amplitude"
                    ]
                ]),
            "Mixpanel": JSON(["someKey": "someVal"])
        ])
        settings.integrations = integrations
        analytics.store.dispatch(action: System.UpdateSettingsAction(settings: settings))
        
        waitUntilStarted(analytics: analytics)

        
        analytics.track(name: "sampleEvent")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let metadata = trackEvent?._metadata
        
        XCTAssertEqual(metadata?.bundled, ["Mixpanel"])
        XCTAssertEqual(metadata?.unbundled.sorted(), ["Amplitude", "Customer.io"])
    }
    
    // Test to ensure bundled and active integrations are populated correctly
    func testDestinationMetadataUnbundled() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let mixpanel = AnyDestination(key: "Mixpanel")
        let outputReader = OutputReaderPlugin()
        
        // we want the output reader on the segment plugin
        // cuz that's the only place the metadata is getting added.
        let segmentDest = analytics.find(pluginType: SegmentDestination.self)
        segmentDest?.add(plugin: outputReader)

        analytics.add(plugin: mixpanel)
        var settings = Settings(writeKey: "123")
        let integrations = try? JSON([
            "Segment.io": JSON([
                "unbundledIntegrations":
                    [
                        "Customer.io"
                    ]
                ]),
            "Mixpanel": JSON(["someKey": "someVal"]),
            "Amplitude": JSON(["someKey": "somVal"]),
            "dest1": JSON(["someKey": "someVal"])
        ])
        settings.integrations = integrations
        analytics.store.dispatch(action: System.UpdateSettingsAction(settings: settings))
        
        waitUntilStarted(analytics: analytics)

        
        analytics.track(name: "sampleEvent")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let metadata = trackEvent?._metadata
        
        XCTAssertEqual(metadata?.bundled, ["Mixpanel"])
        XCTAssertEqual(metadata?.unbundled.sorted(), ["Amplitude", "Customer.io", "dest1"])
    }
}
