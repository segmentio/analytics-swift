import XCTest
@testable import Segment

final class Segment_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(writeKey: "test").build()
        let myDestination = MyDestination(name: "fakeDestination", analytics: analytics)
        myDestination.plugins.add(GooberPlugin(name: "booya", analytics: analytics))
        
        analytics.plugins.add(ZiggyPlugin(name: "crikey", analytics: analytics))
        analytics.plugins.add(myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
    
    func testPluginShutdown() {
        let analytics = Analytics(writeKey: "test").build()
        let myDestination = MyDestination(name: "fakeDestination", analytics: analytics)
        myDestination.plugins.add(GooberPlugin(name: "booya", analytics: analytics))
        
        let expectation = XCTestExpectation(description: "Ziggy Expectation")
        let ziggy = ZiggyPlugin(name: "crikey", analytics: analytics)
        ziggy.completion = {
            expectation.fulfill()
        }
        analytics.plugins.add(ziggy)
        analytics.plugins.add(myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
        analytics.plugins.remove("crikey")
        
        wait(for: [expectation], timeout: 1.0)
    }
}
