//
//  Types.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran


// MARK: - Event Parameter Types

typealias Integrations = Codable
typealias Properties = Codable
typealias Traits = Codable


// MARK: - Event Types

public protocol RawEvent: Codable {
    var type: String? { get set }
    var anonymousId: String? { get set }
    var messageId: String? { get set }
    var timestamp: String? { get set }
    
    var context: JSON? { get set }
    var integrations: JSON? { get set }
    var metrics: [JSON]? { get set }
}

public struct TrackEvent: RawEvent {
    public var type: String? = "track"
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    
    public var event: String?
    public var properties: JSON?
    
    public init(event: String?, properties: JSON?) {
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
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    
    public var userId: String?
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
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    
    public var name: String?
    public var category: String?
    public var properties: JSON?
    
    public init(screenTitle: String? = nil, category: String?, properties: JSON? = nil) {
        self.name = screenTitle
        self.category = category
        self.properties = properties
    }
    
    public init(existing: ScreenEvent) {
        self.init(screenTitle: existing.name, category: existing.category, properties: existing.properties)
        applyRawEventData(event: existing)
    }
}

public struct GroupEvent: RawEvent {
    public var type: String? = "group"
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    public var metrics: [JSON]? = nil
    
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
    
    public var userId: String?
    
    public init(newId: String? = nil) {
        self.userId = newId
    }
    
    public init(existing: AliasEvent) {
        self.init(newId: existing.userId)
        applyRawEventData(event: existing)
    }
}


// MARK: - RawEvent data helpers

extension RawEvent {
    public mutating func applyRawEventData(event: RawEvent?) {
        if let e = event {
            anonymousId = e.anonymousId
            messageId = e.messageId
            timestamp = e.timestamp
            context = e.context
            integrations = e.integrations
        }
    }

    internal func applyRawEventData(store: Store) -> Self {
        var result: Self = self
        
        guard let system: System = store.currentState() else { return self }
        guard let userInfo: UserInfo = store.currentState() else { return self }
        
        result.anonymousId = userInfo.anonymousId
        result.messageId = UUID().uuidString
        result.timestamp = Date().iso8601()
        result.context = system.context
        result.integrations = system.integrations
        
        return result
    }
}
