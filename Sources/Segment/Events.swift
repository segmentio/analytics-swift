//
//  Events.swift
//  Segment
//
//  Created by Cody Garvin on 11/30/20.
//

import Foundation

extension Analytics {
    
    // MARK: - Track
    
    func track<P: Properties, I: Integrations>(name: String, properties: P? = nil, integrations: I? = nil) {
        // ...
    }
    
    // MARK: - Identify
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    public func identify<T: Codable>(userId: String, traits: T) {
        do {
            let jsonTraits = try JSON(traits)
            store.dispatch(action: UserInfo.SetUserIdAndTraitsAction(userId: userId, traits: jsonTraits))
            let event = IdentifyEvent(userId: userId, traits: jsonTraits).applyRawEventData(store: store)
            process(incomingEvent: event)
        } catch {
            assertionFailure("\(error)")
        }
    }
    
    public func identify<T: Codable>(traits: T) {
        do {
            let jsonTraits = try JSON(traits)
            store.dispatch(action: UserInfo.SetTraitsAction(traits: jsonTraits))
            let event = IdentifyEvent(traits: jsonTraits).applyRawEventData(store: store)
            process(incomingEvent: event)
        } catch {
            assertionFailure("\(error)")
        }
    }
    
    public func identify(userId: String) {
        let event = IdentifyEvent(userId: userId, traits: nil).applyRawEventData(store: store)
        process(incomingEvent: event)
    }
    
    // MARK: - Screen
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    func screen<P: Properties>(screenTitle: String, category: String? = nil, properties: P? = nil) {
        // ...
    }

    // MARK: - Group
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    func group<T: Codable>(groupId: String, traits: T? = nil) {
        // ...
    }
    
    // MARK: - Alias
    
    func alias(newId: String) {
        // ...
    }
}
