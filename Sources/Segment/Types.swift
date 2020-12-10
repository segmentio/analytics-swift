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

public struct TrackEvent: RawEvent {
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    
    public let properties: JSON?
    
    public init(properties: JSON?) {
        self.properties = properties
    }
    
}

public struct IdentifyEvent: RawEvent {
    public var anonymousId: String? = nil
    public var messageId: String? = nil
    public var timestamp: String? = nil
    public var context: JSON? = nil
    public var integrations: JSON? = nil
    
    public let userId: String?
    public let traits: JSON?
    
    init(userId: String? = nil, traits: JSON? = nil) {
        self.userId = userId
        self.traits = traits
    }
}


// MARK: - RawEvent data helpers

extension RawEvent {
    internal mutating func applyRawEventData(event: RawEvent?) {
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
