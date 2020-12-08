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
//typealias Traits = Codable


// MARK: - Event Types

protocol Event: Codable {
    var store: Store { get }
    
    var anonymousId: String { get }
    var messageId: String { get }
    var timestamp: String { get }
    
    var userId: String? { get }
    var context: JSON? { get }
    var integrations: JSON? { get }
}

struct TrackEvent: Event {
    private var _store: Store
    var store: Store { return _store }

    let properties: JSON?
    
    init<P: Codable>(store: Store, properties: P?) {
        self._store = store
        var props: JSON? = nil
        do {
            try props = JSON(properties)
        } catch {
            print("Error encoding traits to JSON. \(error)")
        }
        self.properties = props
    }
    
    init(store: Store) {
        self._store = store
        self.properties = nil
    }
}

struct IdentifyEvent: Event {
    private var _store: Store
    var store: Store { return _store }
    
    var traits: JSON? = nil
    
    init<T: Codable>(store: Store, traits: T?) {
        self._store = store
        self.traits = try? JSON(traits)
    }
    /*
    init(store: Store) {
        self._store = store
        self.traits = nil
    }*/
}

/*
struct IdentifyEvent<T: Codable>: Event {
    private var _store: Store
    var store: Store { return _store }
    
    var traits: T? = nil
    
    init(store: Store, traits: T?) {
        self._store = store
        self.traits = traits
    }
}
*/


/*
public struct Event {
    public enum TopLevelKeys: String {
        case timestamp = "timestamp"
        case anonymousId = "anonymousId"
        case messageId = "messageId"
        case userId = "userId"
        case context = "context"
        case integrations = "integrations"
        case properties = "properties"
        case traits = "traits"
    }
    
    public let type: EventType
    public let messageId: String
    public let timestamp: Date
    public let data: JSON?
    
    public init() {
        self.type = .track
        self.messageId = ""
        self.timestamp = Date()
        self.data = nil
    }
    
    public init(store: Store, type: EventType) {
        let userInfo: UserInfo = store.currentState()!// else { assertionFailure("how did we manage to get here?"); return }
        let system: System = store.currentState()!// else { assertionFailure("how did we manage to get here?"); return }

        let anonymousId = userInfo.anonymousId
        let userId = userInfo.userId
        let context = system.context
        let integrations = system.integrations
        
        self.type = type
        self.timestamp = Date()
        self.messageId = UUID().uuidString
        
        let initialValues: [String: Codable?] = [
            TopLevelKeys.timestamp.rawValue: timestamp,
            TopLevelKeys.anonymousId.rawValue: anonymousId,
            TopLevelKeys.userId.rawValue: userId,
            TopLevelKeys.context.rawValue: context,
            TopLevelKeys.integrations.rawValue: integrations
        ]
        
        var initialData: JSON? = nil
        do {
            initialData = try JSON(initialValues)
        } catch {
            print(error)
        }
        self.data = initialData
    }
}*/


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
/*
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
*/

// MARK: - Event Extensions

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

// MARK: - Unspecified Objects

struct NoTraits: Codable {}
struct NoProperties: Codable {}
