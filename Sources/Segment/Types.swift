//
//  Types.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran

// MARK: - Event Parameter Types

typealias Properties = Codable
typealias Traits = Codable
typealias Integrations = Codable

// MARK: - Event Types

enum EventType: Int {
    case track
    case identify
    case screen
    case alias
    case group
}

public struct Event {
    let store: Store
    let type: EventType
    let messageId: String
    let timestamp: Date
    let data: JSON?
}


/*
public class Event: Codable {
    public let anonymousId: String
    public let messageId: String
    public let timestamp: Date
    
    public let userId: String?
    public let context: JSON?
    public let integrations: JSON?
    
    internal init(timeline: Timeline) {
        guard let userInfo: UserInfo = timeline.store.currentState() else { assertionFailure("how did we manage to get here?") }
        guard let system: System = timeline.store.currentState() else { assertionFailure("how did we manage to get here?") }

        anonymousId = userInfo.anonymousId
        userId = userInfo.userId
        timestamp = Date()
        context = system.context
        integrations = system.integrations
    }
    
    public init(event: Event) {
        anonymousId = event.anonymousId
        userId = event.userId
        timestamp = event.timestamp
        context = event.context
        integrations = event.integrations
    }
}
 */

public struct IdentifyEvent: Event {
    public var store: Store?
    
    public var anonymousId: String
    
    public var messageId: String
    
    public var timestamp: Date
    
    public var userId: String?
    
    public var context: JSON?
    
    public var integrations: JSON?
    
    public let traits: JSON?
    
    internal init(traits: Traits?) {
        //self.traits = traits
    }
}


