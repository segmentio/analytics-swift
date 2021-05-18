//
//  Events.swift
//  Segment
//
//  Created by Cody Garvin on 11/30/20.
//

import Foundation

extension Analytics {
    
    // MARK: - Track
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    
    public func track<P: Codable>(name: String, properties: P?) {
        do {
            if let properties = properties {
                let jsonProperties = try JSON(with: properties)
                let event = TrackEvent(event: name, properties: jsonProperties)
                process(incomingEvent: event)
            } else {
                let event = TrackEvent(event: name, properties: nil)
                process(incomingEvent: event)
            }
            
        } catch {
            exceptionFailure("\(error)")
        }
    }
    
    public func track(name: String, properties: [String: Any]?) {
        var props: JSON? = nil
        if let properties = properties {
            do {
                props = try JSON(properties)
            } catch {
                exceptionFailure("\(error)")
            }
        }
        let event = TrackEvent(event: name, properties: props)
        process(incomingEvent: event)
    }
    
    public func track(name: String) {
        track(name: name, properties: nil as TrackEvent?)
    }
    
    // MARK: - Identify
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    
    
    /// Associate a user with their unique ID and record traits about them.
    /// - Parameters:
    ///   - userId: A database ID (or email address) for this user. If you don't have a userId
    ///     but want to record traits, you should pass nil. For more information on how we
    ///     generate the UUID and Apple's policies on IDs, see https://segment.io/libraries/ios#ids
    ///   - traits: A dictionary of traits you know about the user. Things like: email, name, plan, etc.
    public func identify<T: Codable>(userId: String, traits: T) {
        do {
            let jsonTraits = try JSON(with: traits)
            store.dispatch(action: UserInfo.SetUserIdAndTraitsAction(userId: userId, traits: jsonTraits))
            let event = IdentifyEvent(userId: userId, traits: jsonTraits)
            process(incomingEvent: event)
        } catch {
            exceptionFailure("\(error)")
        }
    }
    
    /// Associate a user with their unique ID and record traits about them.
    /// - Parameters:
    ///   - traits: A dictionary of traits you know about the user. Things like: email, name, plan, etc.
    public func identify<T: Codable>(traits: T) {
        do {
            let jsonTraits = try JSON(with: traits)
            store.dispatch(action: UserInfo.SetTraitsAction(traits: jsonTraits))
            let event = IdentifyEvent(traits: jsonTraits)
            process(incomingEvent: event)
        } catch {
            exceptionFailure("\(error)")
        }
    }

    /// Associate a user with their unique ID and record traits about them.
    /// - Parameters:
    ///   - userId: A database ID (or email address) for this user. If you don't have a userId
    ///     but want to record traits, you should pass nil. For more information on how we
    ///     generate the UUID and Apple's policies on IDs, see https://segment.io/libraries/ios#ids
    public func identify(userId: String) {
        let event = IdentifyEvent(userId: userId, traits: nil)
        store.dispatch(action: UserInfo.SetUserIdAction(userId: userId))
        process(incomingEvent: event)
    }
    
    // MARK: - Screen
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    public func screen<P: Codable>(screenTitle: String, category: String? = nil, properties: P?) {
        do {
            if let properties = properties {
                let jsonProperties = try JSON(with: properties)
                let event = ScreenEvent(screenTitle: screenTitle, category: category, properties: jsonProperties)
                process(incomingEvent: event)
            } else {
                let event = ScreenEvent(screenTitle: screenTitle, category: category)
                process(incomingEvent: event)
            }
        } catch {
            exceptionFailure("\(error)")
        }
    }
    
    public func screen(screenTitle: String, category: String? = nil) {
        screen(screenTitle: screenTitle, category: category, properties: nil as ScreenEvent?)
    }

    // MARK: - Group
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    public func group<T: Codable>(groupId: String, traits: T?) {
        do {
            if let traits = traits {
                let jsonTraits = try JSON(with: traits)
                let event = GroupEvent(groupId: groupId, traits: jsonTraits)
                process(incomingEvent: event)
            } else {
                let event = GroupEvent(groupId: groupId)
                process(incomingEvent: event)
            }
        } catch {
            exceptionFailure("\(error)")
        }
    }
    
    public func group(groupId: String) {
        group(groupId: groupId, traits: nil as GroupEvent?)
    }
    
    // MARK: - Alias
    /* will possibly deprecate this ... TBD */
    /*
    public func alias(newId: String) {
        let userInfo: UserInfo? = store.currentState()
        
        let event = AliasEvent(newId: newId)
        store.dispatch(action: UserInfo.SetUserIdAction(userId: newId))
        process(incomingEvent: event)
    }
    */
}
