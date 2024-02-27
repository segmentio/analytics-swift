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
        
        waitUntilStarted(analytics: analytics)
        checkIfLeaked(analytics)
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
        
        waitUntilStarted(analytics: analytics)
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

    func testDestinationInitialUpdateOnlyOnce() {
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

        let ziggy1 = ZiggyPlugin()
        analytics.add(plugin: myDestination)
        analytics.add(plugin: ziggy1)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "testDestinationEnabled")

        let ziggy2 = ZiggyPlugin()
        analytics.add(plugin: ziggy2)

        let dest = analytics.find(key: myDestination.key)
        XCTAssertNotNil(dest)
        XCTAssertTrue(dest is MyDestination)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(myDestination.receivedInitialUpdate, 1)
        XCTAssertEqual(ziggy1.receivedInitialUpdate, 1)
        XCTAssertEqual(ziggy2.receivedInitialUpdate, 1)
        
        checkIfLeaked(analytics)
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

    // Linux & Windows don't support XCTExpectFailure
#if !os(Linux) && !os(Windows)
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
        waitUntilStarted(analytics: analytics)
    }

    func testContext() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

#if !os(watchOS) && !os(Linux)
        // prime the pump for userAgent, since it's retrieved async.
        let vendorSystem = VendorSystem.current
        while vendorSystem.userAgent == nil {
            RunLoop.main.run(until: Date.distantPast)
        }
#endif

        waitUntilStarted(analytics: analytics)

        // add a referrer
        analytics.openURL(URL(string: "https://google.com")!)

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

        let referrer = context?["referrer"] as! [String: Any]
        XCTAssertEqual(referrer["url"] as! String, "https://google.com")

        // this key not present on watchOS (doesn't have webkit)
#if !os(watchOS)
        XCTAssertNotNil(context?["userAgent"], "userAgent missing!")
#endif

        // these keys not present on linux or Windows
#if !os(Linux) && !os(Windows)
        XCTAssertNotNil(context?["app"], "app missing!")
        XCTAssertNotNil(context?["locale"], "locale missing!")
#endif
    }


    func testContextWithUserAgent() {
        let configuration = Configuration(writeKey: "test")
        configuration.userAgent("testing user agent")
        let analytics = Analytics(configuration: configuration)
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

#if !os(watchOS) && !os(Linux)
        // prime the pump for userAgent, since it's retrieved async.
        let vendorSystem = VendorSystem.current
        while vendorSystem.userAgent == nil {
            RunLoop.main.run(until: Date.distantPast)
        }
#endif

        waitUntilStarted(analytics: analytics)

        // add a referrer
        analytics.openURL(URL(string: "https://google.com")!)

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

        let referrer = context?["referrer"] as! [String: Any]
        XCTAssertEqual(referrer["url"] as! String, "https://google.com")

        XCTAssertEqual(context?["userAgent"] as! String, "testing user agent")

        // these keys not present on linux or Windows
#if !os(Linux) && !os(Windows)
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

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
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
        let analytics = Analytics(configuration: Configuration(writeKey: "testFlush_do_not_reuse_this_writekey").flushInterval(9999).flushAt(9999))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))

        let currentBatchCount = analytics.storage.eventFiles(includeUnfinished: true).count

        analytics.flush()
        analytics.track(name: "test")

        let batches = analytics.storage.eventFiles(includeUnfinished: true)
        let newBatchCount = batches.count
        // 1 new temp file
        XCTAssertTrue(newBatchCount == currentBatchCount + 1, "New Count (\(newBatchCount)) should be \(currentBatchCount) + 1")
    }

    func testEnabled() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "enabled")

        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        XCTAssertTrue(trackEvent!.event == "enabled")

        outputReader.lastEvent = nil
        analytics.enabled = false
        analytics.track(name: "notEnabled")

        let noEvent = outputReader.lastEvent
        XCTAssertNil(noEvent)

        analytics.enabled = true
        analytics.track(name: "enabled")

        let newEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        XCTAssertTrue(newEvent!.event == "enabled")
    }

    func testSetFlushIntervalAfter() {
        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))
        let intervalPolicy = IntervalBasedFlushPolicy(interval: 35)
        analytics.add(flushPolicy: intervalPolicy)

        waitUntilStarted(analytics: analytics)

        XCTAssertTrue(intervalPolicy.flushTimer!.interval == 35)

        analytics.flushInterval = 60

        RunLoop.main.run(until: Date.distantPast)

        XCTAssertTrue(intervalPolicy.flushTimer!.interval == 60)
    }

    func testSetFlushAtAfter() {
        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))
        let countPolicy = CountBasedFlushPolicy(count: 23)
        analytics.add(flushPolicy: countPolicy)

        waitUntilStarted(analytics: analytics)

        XCTAssertTrue(analytics.configuration.values.flushAt == 23)

        analytics.flushAt = 1

        let event = TrackEvent(event: "blah", properties: nil)

        countPolicy.updateState(event: event)

        RunLoop.main.run(until: Date.distantPast)

        XCTAssertTrue(countPolicy.shouldFlush() == true)
        XCTAssertTrue(analytics.configuration.values.flushAt == 1)
    }

    func testPurgeStorage() {
        // Use a specific writekey to this test so we do not collide with other cached items.
        let analytics = Analytics(configuration: Configuration(writeKey: "testFlush_do_not_reuse_this_writekey_either")
            .flushInterval(9999)
            .flushAt(9999)
            .operatingMode(.synchronous))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))

        let currentPendingCount = analytics.pendingUploads!.count

        XCTAssertEqual(currentPendingCount, 1)

        analytics.flush()
        analytics.track(name: "test")

        analytics.flush()
        analytics.track(name: "test")

        analytics.flush()
        analytics.track(name: "test")

        var newPendingCount = analytics.pendingUploads!.count
        XCTAssertEqual(newPendingCount, 1)

        let pending = analytics.pendingUploads!
        analytics.purgeStorage(fileURL: pending.first!)

        newPendingCount = analytics.pendingUploads!.count
        XCTAssertEqual(newPendingCount, 0)

        analytics.purgeStorage()
        newPendingCount = analytics.pendingUploads!.count
        XCTAssertEqual(newPendingCount, 0)
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
        weak var analytics: Analytics?

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

    func testRequestFactory() {
        let config = Configuration(writeKey: "testSequential").requestFactory { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Encoding"), "gzip")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")
            XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")!.contains("analytics-ios/"))
            return request
        }.errorHandler { error in
            switch error {
            case AnalyticsError.networkServerRejected(_):
                // we expect this one; it's a bogus writekey
                break;
            default:
                XCTFail("\(error)")
            }
        }
        let analytics = Analytics(configuration: config)
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "something")

        analytics.flush()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
    }

    func testEnrichment() {
        var sourceHit: Bool = false
        let sourceEnrichment: EnrichmentClosure = { event in
            print("source enrichment applied")
            sourceHit = true
            return event
        }

        var destHit: Bool = true
        let destEnrichment: EnrichmentClosure = { event in
            print("destination enrichment applied")
            destHit = true
            return event
        }

        let config = Configuration(writeKey: "testEnrichments")
        let analytics = Analytics(configuration: config)
        analytics.storage.hardReset(doYouKnowHowToUseThis: true)
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

        analytics.add(enrichment: sourceEnrichment)

        let segment = analytics.find(pluginType: SegmentDestination.self)
        segment?.add(enrichment: destEnrichment)

        waitUntilStarted(analytics: analytics)

        analytics.track(name: "something")

        analytics.flush()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))

        XCTAssertTrue(sourceHit)
        XCTAssertTrue(destHit)

    }

    func testSharedInstance() {
        Analytics.firstInstance = nil

        let dead = Analytics.shared()
        XCTAssertTrue(dead.isDead)

        let alive = Analytics(configuration: Configuration(writeKey: "1234"))
        XCTAssertFalse(alive.isDead)

        let shared = Analytics.shared()
        XCTAssertFalse(shared.isDead)

        XCTAssertTrue(alive === shared)

        let alive2 = Analytics(configuration: Configuration(writeKey: "ABCD"))
        let shared2 = Analytics.shared()
        XCTAssertFalse(alive2 === shared2)
        XCTAssertTrue(shared2 === shared)

    }

    func testAsyncOperatingMode() throws {
        // Use a specific writekey to this test so we do not collide with other cached items.
        let analytics = Analytics(configuration: Configuration(writeKey: "testFlush_asyncMode")
            .flushInterval(9999)
            .flushAt(9999)
            .operatingMode(.asynchronous))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        @Atomic var completionCalled = false

        // put an event in the pipe ...
        analytics.track(name: "completion test1")
        // flush it, that'll get us an upload going
        analytics.flush {
            // verify completion is called.
            completionCalled = true
        }

        while !completionCalled {
            RunLoop.main.run(until: Date.distantPast)
        }

        XCTAssertTrue(completionCalled)
        XCTAssertEqual(analytics.pendingUploads!.count, 0)
    }

    func testSyncOperatingMode() throws {
        // Use a specific writekey to this test so we do not collide with other cached items.
        let analytics = Analytics(configuration: Configuration(writeKey: "testFlush_syncMode")
            .flushInterval(9999)
            .flushAt(9999)
            .operatingMode(.synchronous))

        waitUntilStarted(analytics: analytics)

        analytics.storage.hardReset(doYouKnowHowToUseThis: true)

        @Atomic var completionCalled = false

        // put an event in the pipe ...
        analytics.track(name: "completion test1")
        // flush it, that'll get us an upload going
        analytics.flush {
            // verify completion is called.
            completionCalled = true
        }

        // completion shouldn't be called before flush returned.
        XCTAssertTrue(completionCalled)
        XCTAssertEqual(analytics.pendingUploads!.count, 0)

        // put another event in the pipe.
        analytics.track(name: "completion test2")
        analytics.flush()

        // flush shouldn't return until all uploads are done, cuz
        // it's running in sync mode.
        XCTAssertEqual(analytics.pendingUploads!.count, 0)
    }

    func testFindAll() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "testFindAll")
            .flushInterval(9999)
            .flushAt(9999)
            .operatingMode(.synchronous))

        analytics.add(plugin: ZiggyPlugin())
        analytics.add(plugin: ZiggyPlugin())
        analytics.add(plugin: ZiggyPlugin())

        let myDestination = MyDestination()
        myDestination.add(plugin: GooberPlugin())
        myDestination.add(plugin: GooberPlugin())

        analytics.add(plugin: myDestination)

        waitUntilStarted(analytics: analytics)

        let ziggysFound = analytics.findAll(pluginType: ZiggyPlugin.self)
        let goobersFound = myDestination.findAll(pluginType: GooberPlugin.self)

        XCTAssertEqual(ziggysFound!.count, 3)
        XCTAssertEqual(goobersFound!.count, 2)
    }
    
    func testJSONNaNDefaultHandlingZero() throws {
        // notice we didn't set the nan handling option.  zero is the default.
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "test track", properties: ["TestNaN": Double.nan])
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        XCTAssertTrue(trackEvent?.event == "test track")
        XCTAssertTrue(trackEvent?.type == "track")
        let d: Double? = trackEvent?.properties?.value(forKeyPath: "TestNaN")
        XCTAssertTrue(d! == 0)
    }
    
    func testJSONNaNHandlingNull() throws {
        let analytics = Analytics(configuration: Configuration(writeKey: "test")
            .jsonNonConformingNumberStrategy(.null)
        )
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "test track", properties: ["TestNaN": Double.nan])
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        XCTAssertTrue(trackEvent?.event == "test track")
        XCTAssertTrue(trackEvent?.type == "track")
        let d: Double? = trackEvent?.properties?.value(forKeyPath: "TestNaN")
        XCTAssertNil(d)
    }
    
    // Linux doesn't know what URLProtocol is and on watchOS it somehow works differently and isn't hit.
    #if !os(Linux) && !os(watchOS)
    func testFailedSegmentResponse() throws {
        //register our network blocker (returns 400 response)
        guard URLProtocol.registerClass(FailedNetworkCalls.self) else {
            XCTFail(); return }
        
        let analytics = Analytics(configuration: Configuration(writeKey: "networkTest"))
        
        waitUntilStarted(analytics: analytics)
        
        //set the httpClient to use our blocker session
        let segment = analytics.find(pluginType: SegmentDestination.self)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForRequest = 60
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.protocolClasses = [FailedNetworkCalls.self]
        configuration.httpAdditionalHeaders = [
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": "Basic test",
            "User-Agent": "analytics-ios/\(Analytics.version())"
        ]
        
        let blockSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        
        segment?.httpClient?.session = blockSession
        
        analytics.track(name: "test track", properties: ["Malformed Paylod": "My Failed Prop"])
        
        //get fileUrl from track call
        let storedEvents: [URL]? = analytics.storage.read(.events)
        let fileURL = storedEvents![0]
        
        
        let expectation = XCTestExpectation()
        
        analytics.flush {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let newStoredEvents: [URL]? = analytics.storage.read(.events)
        
        XCTAssert(!(newStoredEvents?.contains(fileURL))!)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    #endif
}
