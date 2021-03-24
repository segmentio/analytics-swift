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
        let anonId = analytics.anonymousId()
        
        XCTAssertTrue(anonId != nil)
        XCTAssertTrue(anonId != "")
        XCTAssertTrue(anonId.count == 36) // it's a UUID y0.
    }
}
