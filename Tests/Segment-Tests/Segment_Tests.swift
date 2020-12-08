import XCTest
@testable import Segment

struct MyTraits: Codable {
    let email: String?
}

final class Segment_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(writeKey: "test").build()
        
        //let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify<NoTraits>(userId: "brandon")
        
        //analytics.track("myevent")
        
        //print("\(event)")
    }
}
