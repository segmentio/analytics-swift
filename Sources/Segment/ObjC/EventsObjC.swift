//
//  File.swift
//  
//
//  Created by Cody Garvin on 6/10/21.
//

import Foundation

// MARK: - Objective-C friendly methods
extension Analytics {
    
    // MARK: - Objective-C Track
    
    /// Associate a user with their unique ID and record traits about them.
    /// - Parameters:
    ///   - userId: A database ID (or email address) for this user. If you don't have a userId
    ///     but want to record traits, you should pass nil. For more information on how we
    ///     generate the UUID and Apple's policies on IDs, see https://segment.io/libraries/ios#ids
    ///   - properties: A dictionary of traits you know about the user. Things like: email, name, plan, etc.
    @objc
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
    
    
    // MARK: - Objective-C Identify
    
    /// Associate a user with their unique ID and record traits about them.
    /// - Parameters:
    ///   - userId: A database ID (or email address) for this user. If you don't have a userId
    ///     but want to record traits, you should pass nil. For more information on how we
    ///     generate the UUID and Apple's policies on IDs, see https://segment.io/libraries/ios#ids
    ///   - traits: A dictionary of traits you know about the user. Things like: email, name, plan, etc.
    @objc
    public func identify(userId: String, traits: [String: AnyHashable]?) {
        do {
            if let traits = traits {
                let traits = try JSON(traits as Any)
                let event = IdentifyEvent(userId: userId, traits: traits)
                process(incomingEvent: event)
            } else {
                let event = IdentifyEvent(userId: userId, traits: nil)
                process(incomingEvent: event)
            }

        } catch {
            exceptionFailure("Could not parse traits.")
        }
    }
    
    /// Associate a user with traits about them.
    /// - Parameters:
    ///   - traits: A dictionary of traits you know about the user. Things like: email, name, plan, etc.
    @objc
    public func identify(traits: [String: AnyHashable]) {
        do {
            let traits = try JSON(traits as Any)
            let event = IdentifyEvent(userId: nil, traits: traits)
            process(event: event)
        } catch {
            exceptionFailure("Could not parse traits.")
        }
    }
    
    
    // MARK: - Objective-C Screen
    
    /// Track a screen change with a title, category and other properties.
    /// - Parameters:
    ///   - screenTitle: The title of the screen being tracked.
    ///   - category: A category to the type of screen if it applies.
    ///   - properties: Any extra metadata associated with the screen. e.g. method of access, size, etc.
    @objc
    public func screen(screenTitle: String, category: String? = nil, properties: [String: AnyHashable]?) {
        var event = ScreenEvent(screenTitle: screenTitle, category: category, properties: nil)
        if let properties = properties {
            do {
                let jsonProperties = try JSON(properties)
                event = ScreenEvent(screenTitle: screenTitle, category: category, properties: jsonProperties)
            } catch {
                exceptionFailure("Could not parse properties.")
            }
        }
        process(event: event)
    }
    
    
    // MARK: - Objective-C Group
    
    
    /// Associate a user with a group such as a company, organization, project, etc.
    /// - Parameters:
    ///   - groupId: A unique identifier for the group identification in your system.
    ///   - traits: Traits of the group you may be interested in such as email, phone or name.
    @objc
    public func group(groupId: String, traits: [String: AnyHashable]?) {
        var event = GroupEvent(groupId: groupId)
        if let traits = traits {
            do {
                let jsonTraits = try JSON(traits)
                event = GroupEvent(groupId: groupId, traits: jsonTraits)
            } catch {
                exceptionFailure("Could not parse traits.")
            }
        }
        process(event: event)
    }
}
