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
        let analytics = Analytics(configuration: Configuration(writeKey: "test"))
        let myDestination = MyDestination(name: "fakeDestination")
        myDestination.add(plugin: GooberPlugin(name: "booya"))
        
        analytics.add(plugin: ZiggyPlugin(name: "crikey"))
        analytics.add(plugin: myDestination)
        
        let traits = MyTraits(email: "brandon@redf.net")
        analytics.identify(userId: "brandon", traits: traits)
    }
}


