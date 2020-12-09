import XCTest
@testable import Segment

struct MyTraits: Codable {
    let email: String?
}

class MyExtension: EventExtension {
    let type: ExtensionType
    let name: String
    var analytics: Analytics? = nil
    
    required init(type: ExtensionType, name: String) {
        self.name = name
        self.type = type
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        let newEvent = IdentifyEvent(userId: "goober", traits: event.traits)
        return newEvent
        //return nil
    }
}

final class Segment_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(writeKey: "test").build()
        
        analytics.extensions.add(MyExtension(type: .sourceEnrichment, name: "crikey"))
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
}
