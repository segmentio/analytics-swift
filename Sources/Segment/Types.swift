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
    var anonymousId: String? { get set }
    var messageId: String? { get set }
    var timestamp: String? { get set }
    
    var context: JSON? { get set }
    var integrations: JSON? { get set }
}

struct TrackEvent: RawEvent {
    var anonymousId: String? = nil
    var messageId: String? = nil
    var timestamp: String? = nil
    var context: JSON? = nil
    var integrations: JSON? = nil
    
    let properties: JSON?
    
    init(properties: JSON?) {
        self.properties = properties
    }
    
}

struct IdentifyEvent: RawEvent {
    var anonymousId: String? = nil
    var messageId: String? = nil
    var timestamp: String? = nil
    var context: JSON? = nil
    var integrations: JSON? = nil
    
    let userId: String?
    let traits: JSON?
    
    init(userId: String? = nil, traits: JSON? = nil) {
        self.userId = userId
        self.traits = traits
    }
}

extension RawEvent {
    func applyRawEventData(store: Store) -> Self {
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

// MARK: - Event Extensions
/*
internal protocol StoreAccess {
    var store: Store { get set }
}

extension Event {
    var anonymousId: String {
        return "1234"
    }
    
    var messageId: String {
        return "1234"
    }
    var timestamp: String {
        return "12/12/2020"
    }
    
    var userId: String? {
        return "brandon"
    }
    var context: JSON? {
        return nil
    }
    var integrations: JSON? {
        return nil
    }
}
*/
// MARK: - Unspecified Objects

struct NoTraits: Codable {}
struct NoProperties: Codable {}
