//
//  SafelyDefinitions.swift
//
//
//  Created by Alan Charles on 1/31/24.
//

import Foundation
import Safely

struct Scenarios {
    static let nullDefaultValues = SafeScenario(
        description: "Guard against null getting set as a user default value",
        implementor: "@alanjcharles")

    static let failedToWriteEvent = SafeScenario(
        description: "Failed to write event to disk",
        implementor: "@alanjcharles")

    static let failedToFlushPlugin = SafeScenario(
        description: "Plugin failed to flush events",
        implementor: "@alanjcharles")
    
    static let failedToFlushEventPlugin = SafeScenario(
        description: "Event Plugin failed to flush events",
        implementor: "@alanjcharles")

    static let failedToResetPlugin = SafeScenario(
        description: "Plugin failed to reset",
        implementor: "@alanjcharles")

    static let failedToConfigurePlugin = SafeScenario(
        description: "Plugin failed to configure",
        implementor: "@alanjcharles")

    static let failedToUpdatePlugin = SafeScenario(
        description: "Plugin failed to update",
        implementor: "@alanjcharles")

    static let failedToProcessEnrichment = SafeScenario(
        description: "Plugin failed to execute enrichment",
        implementor: "@alanjcharles")

    static let failedToShutdownPlugin = SafeScenario(
        description: "Plugin failed to shutdown",
        implementor: "@alanjcharles")
}
