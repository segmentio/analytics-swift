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
        let myDestination = MyDestination(name: "fakeDestination", analytics: analytics)
        myDestination.plugins.add(GooberPlugin(name: "booya", analytics: analytics))
        
        analytics.plugins.add(ZiggyPlugin(name: "crikey", analytics: analytics))
        analytics.plugins.add(myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
}


