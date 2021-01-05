import XCTest
@testable import Segment

final class Segment_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(writeKey: "test").build()
        let myDestination = MyDestination(name: "fakeDestination")
        myDestination.extensions.add(GooberExtension(name: "booya"))
        
        analytics.extensions.add(ZiggyExtension(name: "crikey"))
        analytics.extensions.add(myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
    
    func testExtensionShutdown() {
        let analytics = Analytics(writeKey: "test").build()
        let myDestination = MyDestination(name: "fakeDestination")
        myDestination.extensions.add(GooberExtension(name: "booya"))
        
        let expectation = XCTestExpectation(description: "Ziggy Expectation")
        let ziggy = ZiggyExtension(name: "crikey")
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
    
    // MARK: - Helpers
    struct MyTraits: Codable {
        let email: String?
    }

    class GooberExtension: EventExtension {
        let type: ExtensionType
        let name: String
        
        required init(name: String) {
            self.name = name
            self.type = .enrichment
        }
        
        func identify(event: IdentifyEvent) -> IdentifyEvent? {
            var newEvent = IdentifyEvent(existing: event)
            newEvent.userId = "goober"
            return newEvent
            //return nil
        }
    }

    class ZiggyExtension: EventExtension {
        let type: ExtensionType
        let name: String
        var completion: (() -> Void)?
        
        required init(name: String) {
            self.name = name
            self.type = .enrichment
        }
        
        func identify(event: IdentifyEvent) -> IdentifyEvent? {
            var newEvent = IdentifyEvent(existing: event)
            newEvent.userId = "ziggy"
            return newEvent
            //return nil
        }
        
        func shutdown() {
            completion?()
        }
    }

    class MyDestination: DestinationExtension {
        var extensions: Extensions
        let type: ExtensionType
        let name: String
        
        required init(name: String) {
            self.name = name
            self.type = .destination
            self.extensions = Extensions()
        }
        
        func identify(event: IdentifyEvent) -> IdentifyEvent? {
            return event
        }
    }
}
