//
//  Metrics_Tests.swift
//  Segment-Tests
//
//  Created by Cody Garvin on 12/18/20.
//

import Foundation
import XCTest
@testable import Segment


final class Metrics_Tests: XCTestCase {
    
    func testBaseEventCreation() {
        let analytics = Analytics(writeKey: "test").build()
        let myDestination = MyDestination(name: "fakeDestination")
        myDestination.extensions.add(GooberExtension(name: "booya"))
        
        analytics.extensions.add(ZiggyExtension(name: "crikey"))
        analytics.extensions.add(myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
    
    // MARK: - Helper Classes
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
            let beginningTime = Date()
            var newEvent = IdentifyEvent(existing: event)
            newEvent.userId = "goober"
            sleep(3)
            let endingTime = Date()
            let finalTime = endingTime.timeIntervalSince(beginningTime)
            
            newEvent.addMetric(.gauge, name: "Gauge Test", value: finalTime, tags: ["timing", "function_length"], timestamp: Date())
            
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
            self.extensions = Extensions(analytics: self.analytics)
        }
        
        func identify(event: IdentifyEvent) -> IdentifyEvent? {
            return event
        }
    }
}


