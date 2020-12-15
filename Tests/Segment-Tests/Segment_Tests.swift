import XCTest
@testable import Segment

struct MyTraits: Codable {
    let email: String?
}

class GooberExtension: EventExtension {
    let type: ExtensionType
    let name: String
    var analytics: Analytics? = nil
    
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
    var analytics: Analytics? = nil
    
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
}

class MyDestination: DestinationExtension {
    var extensions: Extensions
    
    let type: ExtensionType
    let name: String
    var analytics: Analytics? = nil
    
    required init(name: String) {
        self.name = name
        self.type = .destination
        self.extensions = Extensions()
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
}

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
    
    class LoggerMock: Logger {
        var closure: ((LogType, String) -> Void)?
        
        override func log(type: LogType, message: String) {
            closure?(type, message)
        }
    }
    
    func testLogging() {
        
        let analytics = Analytics(writeKey: "test").build()
        
        let expectation = XCTestExpectation(description: "Called")
        
        let mockLogger = LoggerMock(name: "Blah")
        mockLogger.closure = { (type, message) in
            expectation.fulfill()
            
            XCTAssertEqual(type, .info, "Type not correctly passed")
            XCTAssertEqual(message, "Something Other Than Awesome", "Message not correctly passed")
        }
        analytics.extensions.add(mockLogger)
        analytics.log(message: "Something Other Than Awesome")
        wait(for: [expectation], timeout: 1.0)
    }
}
