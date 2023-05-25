//
//  SafeDefinitions.swift
//  Segment
//
//  Created by Alan Charles on 5/25/23.
//

import Foundation
import Safely

struct Scenarios {
    static let nullDefaultValues = SafeScenario(
        description: "Guard against null getting set as a user default value",
        implementor: "@alanjcharles")
    
    static let failedToWriteEvent = SafeScenario(
        description: "Failed to write event to disk...something more descriptive",
        implementor: "@alanjcharles")
}
