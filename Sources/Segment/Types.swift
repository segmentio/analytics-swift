//
//  Types.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran

// MARK: - Supplementary Types

public struct DestinationMetadata: Codable {
    var bundled: [String] = []
    var unbundled: [String] = []
    var bundledIds: [String] = []
}

// MARK: - Event Types

public protocol RawEvent: Codable {
    var type: String? { get set }
    var anonymousId: String? { get set }
    var messageId: String? { get set }
    var userId: String? { get set }
    var timestamp: String? { get set }
    
    var context: JSON? { get set }
    var integrations: JSON? { get set }
    var metrics: [JSON]? { get set }
    var _metadata: DestinationMetadata? { get set }
}

public struct TrackEvent: RawEvent {
    public var type: String? = "track"
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var userId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    public var _metadata: DestinationMetadata? = nil
    
    public var event: String
    public var properties: JSON?
    
    public init(event: String, properties: JSON?) {
        self.event = event
        self.properties = properties
    }
    
    public init(existing: TrackEvent) {
        self.init(event: existing.event, properties: existing.properties)
        applyRawEventData(event: existing)
    }
}

public struct IdentifyEvent: RawEvent {
    public var type: String? = "identify"
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var userId: String?
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    public var _metadata: DestinationMetadata? = nil
    
    public var traits: JSON?
    
    
    public init(userId: String? = nil, traits: JSON? = nil) {
        self.userId = userId
        self.traits = traits
    }
    
    public init(existing: IdentifyEvent) {
        self.init(userId: existing.userId, traits: existing.traits)
        applyRawEventData(event: existing)
    }
}

public struct ScreenEvent: RawEvent {
    public var type: String? = "screen"
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var userId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    public var _metadata: DestinationMetadata? = nil
    
    public var name: String?
    public var category: String?
    public var properties: JSON?
    
    public init(title: String? = nil, category: String?, properties: JSON? = nil) {
        self.name = title
        self.category = category
        self.properties = properties
    }
    
    public init(existing: ScreenEvent) {
        self.init(title: existing.name, category: existing.category, properties: existing.properties)
        applyRawEventData(event: existing)
    }
}

public struct GroupEvent: RawEvent {
    public var type: String? = "group"
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var userId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    public var _metadata: DestinationMetadata? = nil
    
    public var groupId: String?
    public var traits: JSON?
    
    public init(groupId: String? = nil, traits: JSON? = nil) {
        self.groupId = groupId
        self.traits = traits
    }
    
    public init(existing: GroupEvent) {
        self.init(groupId: existing.groupId, traits: existing.traits)
        applyRawEventData(event: existing)
    }
}

public struct AliasEvent: RawEvent {
    public var type: String? = "alias"
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    public var _metadata: DestinationMetadata? = nil
    
    public var userId: String? = nil
    public var previousId: String? = nil
    
    public init(newId: String?, previousId: String? = nil) {
        self.userId = newId
        self.previousId = previousId
    }
    
    public init(existing: AliasEvent) {
        self.init(newId: existing.userId, previousId: existing.previousId)
        applyRawEventData(event: existing)
    }
}

// MARK: - RawEvent conveniences

internal struct IntegrationConstants {
    static let allIntegrationsKey = "All"
}

extension RawEvent {
    /**
     Disable all cloud-mode integrations for this event, except for any specific keys given.
     This will preserve any per-integration specific settings if the integration is to remain enabled.
     - Parameters:
        - exceptKeys: A list of integration keys to exclude from disabling.
     */
    public mutating func disableCloudIntegrations(exceptKeys: [String]? = nil) {
        guard let existing = integrations?.dictionaryValue else {
            // this shouldn't happen, might oughta log it.
            Analytics.segmentLog(message: "Unable to get what should be a valid list of integrations from event.", kind: .error)
            return
        }
        var new = [String: Any]()
        new[IntegrationConstants.allIntegrationsKey] = false
        if let exceptKeys = exceptKeys {
            for key in exceptKeys {
                if let value = existing[key], value is [String: Any] {
                    new[key] = value
                } else {
                    new[key] = true
                }
            }
        }
        
        do {
            integrations = try JSON(new)
        } catch {
            // this shouldn't happen, log it.
            Analytics.segmentLog(message: "Unable to convert list of integrations to JSON. \(error)", kind: .error)
        }
    }
    
    /**
     Enable all cloud-mode integrations for this event, except for any specific keys given.
     - Parameters:
        - exceptKeys: A list of integration keys to exclude from enabling.
     */
    public mutating func enableCloudIntegrations(exceptKeys: [String]? = nil) {
        var new = [String: Any]()
        new[IntegrationConstants.allIntegrationsKey] = true
        if let exceptKeys = exceptKeys {
            for key in exceptKeys {
                new[key] = false
            }
        }
        
        do {
            integrations = try JSON(new)
        } catch {
            // this shouldn't happen, log it.
            Analytics.segmentLog(message: "Unable to convert list of integrations to JSON. \(error)", kind: .error)
        }
    }
    
    /**
     Disable a specific cloud-mode integration using it's key name.
     - Parameters:
        - key: The key name of the integration to disable.
     */
    public mutating func disableIntegration(key: String) {
        guard let existing = integrations?.dictionaryValue else {
            // this shouldn't happen, might oughta log it.
            Analytics.segmentLog(message: "Unable to get what should be a valid list of integrations from event.", kind: .error)
            return
        }
        // we don't really care what the value of this key was before, as
        // a disabled one can only be false.
        var new = existing
        new[key] = false
        
        do {
            integrations = try JSON(new)
        } catch {
            // this shouldn't happen, log it.
            Analytics.segmentLog(message: "Unable to convert list of integrations to JSON. \(error)", kind: .error)
        }
    }
    
    /**
     Enable a specific cloud-mode integration using it's key name.
     - Parameters:
        - key: The key name of the integration to enable.
     */
    public mutating func enableIntegration(key: String) {
        guard let existing = integrations?.dictionaryValue else {
            // this shouldn't happen, might oughta log it.
            Analytics.segmentLog(message: "Unable to get what should be a valid list of integrations from event.", kind: .error)
            return
        }
        
        var new = existing
        // if it's a dictionary already, it's considered enabled, so don't
        // overwrite whatever they may have put there.  If that's not the case
        // just set it to true since that's the only other value it could have
        // to be considered `enabled`.
        if (existing[key] as? [String: Any]) == nil {
            new[key] = true
        }
        
        do {
            integrations = try JSON(new)
        } catch {
            // this shouldn't happen, log it.
            Analytics.segmentLog(message: "Unable to convert list of integrations to JSON. \(error)", kind: .error)
        }
    }
    
}


// MARK: - RawEvent data helpers

extension RawEvent {
    internal mutating func applyRawEventData(event: RawEvent?) {
        if let e = event {
            anonymousId = e.anonymousId
            messageId = e.messageId
            userId = e.userId
            timestamp = e.timestamp
            context = e.context
            integrations = e.integrations
            _metadata = e._metadata
        }
    }

    internal func applyRawEventData(store: Store) -> Self {
        var result: Self = self
        
        guard let userInfo: UserInfo = store.currentState() else { return self }
        
        result.anonymousId = userInfo.anonymousId
        result.userId = userInfo.userId
        result.messageId = UUID().uuidString
        result.timestamp = Date().iso8601()
        result.integrations = try? JSON([String: Any]())
        result._metadata = DestinationMetadata()
        
        return result
    }
}
