import XCTest
@testable import Segment

final class Analytics_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let myDestination = MyDestination(name: "fakeDestination", analytics: analytics)
        myDestination.add(plugin: GooberPlugin(name: "booya", analytics: analytics))
        
        analytics.add(plugin: ZiggyPlugin(name: "crikey", analytics: analytics))
        analytics.add(plugin: myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
    
    func testPluginRemove() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let myDestination = MyDestination(name: "fakeDestination", analytics: analytics)
        myDestination.add(plugin: GooberPlugin(name: "booya", analytics: analytics))
        
        let expectation = XCTestExpectation(description: "Ziggy Expectation")
        let ziggy = ZiggyPlugin(name: "crikey", analytics: analytics)
        ziggy.completion = {
            expectation.fulfill()
        }
        analytics.add(plugin: ziggy)
        analytics.add(plugin: myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
        analytics.remove(pluginName: "crikey")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAnonymousId() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let anonId = analytics.anonymousId
        
        XCTAssertTrue(anonId != "")
        XCTAssertTrue(anonId.count == 36) // it's a UUID y0.
    }
    
    func testDeviceToken() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
        analytics.setDeviceToken("1234")
        analytics.track(name: "token check")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let device = trackEvent?.context?.dictionaryValue
        let token = device?[keyPath: "device.token"] as? String
        XCTAssertTrue(token == "1234")
    }
    
    func testDeviceTokenData() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
        let dataToken = UUID().asData()
        analytics.setDeviceToken(dataToken)
        analytics.track(name: "token check")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        let device = trackEvent?.context?.dictionaryValue
        let token = device?[keyPath: "device.token"] as? String
        XCTAssertTrue(token?.count == 32) // it's a uuid w/o the dashes.  36 becomes 32.
    }
    
    func testTrack() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
        analytics.track(name: "test track")
        
        let trackEvent: TrackEvent? = outputReader.lastEvent as? TrackEvent
        XCTAssertTrue(trackEvent?.event == "test track")
        XCTAssertTrue(trackEvent?.type == "track")
    }
    
    func testIdentify() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))
        
        let identifyEvent: IdentifyEvent? = outputReader.lastEvent as? IdentifyEvent
        XCTAssertTrue(identifyEvent?.userId == "brandon")
        let traits = identifyEvent?.traits?.dictionaryValue
        XCTAssertTrue(traits?["email"] as? String == "blah@blah.com")
    }
    
    func testScreen() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
        analytics.screen(screenTitle: "screen1", category: "category1")
        
        let screen1Event: ScreenEvent? = outputReader.lastEvent as? ScreenEvent
        XCTAssertTrue(screen1Event?.name == "screen1")
        XCTAssertTrue(screen1Event?.category == "category1")
        
        analytics.screen(screenTitle: "screen2", category: "category2", properties: MyTraits(email: "blah@blah.com"))
        
        let screen2Event: ScreenEvent? = outputReader.lastEvent as? ScreenEvent
        XCTAssertTrue(screen2Event?.name == "screen2")
        XCTAssertTrue(screen2Event?.category == "category2")
        let props = screen2Event?.properties?.dictionaryValue
        XCTAssertTrue(props?["email"] as? String == "blah@blah.com")
    }
    
    func testGroup() {
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
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
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
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
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let outputReader = OutputReaderPlugin(name: "outputReader", analytics: analytics)
        analytics.add(plugin: outputReader)
        
        analytics.identify(userId: "brandon", traits: MyTraits(email: "blah@blah.com"))

        let currentBatchCount = analytics.storage.eventFiles(includeUnfinished: true).count
        
        analytics.flush()
        
        analytics.track(name: "test")
        
        let newBatchCount = analytics.storage.eventFiles(includeUnfinished: true).count
        
        // 1 new temp file, and 1 new finished file.
        XCTAssertTrue(newBatchCount == currentBatchCount + 2)
    }
}
