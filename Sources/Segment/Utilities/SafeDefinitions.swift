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
    
    static let failedToFlushPlugin = SafeScenario(
        description: "Plugin failed to flush events",
        implementor: "@alanjcharles")
    
    static let failedToResetPlugin = SafeScenario(
        description: "Plugin failed to reset (?)",
        implementor: "@alanjcharles")
    
    static let failedToConfigurePlugin = SafeScenario(
        description: "Plugin failed to configure (?)",
        implementor: "@alanjcharles")
    
    static let failedToUpdatePlugin = SafeScenario(
        description: "Plugin failed to update (?)",
        implementor: "@alanjcharles")
    
    static let failedToProcessEnrichment = SafeScenario(
        description: "Plugin failed to execute enrichment(?)... need better naming",
        implementor: "@alanjcharles")
    
    static let failedToShutdownPlugin = SafeScenario(
        description: "Plugin failed to shutdown (?)",
        implementor: "@alanjcharles")
}
