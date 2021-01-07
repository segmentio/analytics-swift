import XCTest
@testable import Segment

final class Segment_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(writeKey: "test").build()
        let myDestination = MyDestination(name: "fakeDestination", analytics: analytics)
        myDestination.extensions.add(GooberExtension(name: "booya", analytics: analytics))
        
        analytics.extensions.add(ZiggyExtension(name: "crikey", analytics: analytics))
        analytics.extensions.add(myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
    
    func testExtensionShutdown() {
        let analytics = Analytics(writeKey: "test").build()
        let myDestination = MyDestination(name: "fakeDestination", analytics: analytics)
        myDestination.extensions.add(GooberExtension(name: "booya", analytics: analytics))
        
        let expectation = XCTestExpectation(description: "Ziggy Expectation")
        let ziggy = ZiggyExtension(name: "crikey", analytics: analytics)
        ziggy.completion = {
            expectation.fulfill()
        }
        analytics.extensions.add(ziggy)
        analytics.extensions.add(myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
        analytics.extensions.remove("crikey")
        
        wait(for: [expectation], timeout: 1.0)
    }
}
