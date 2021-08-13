//
//  File.swift
//  
//
//  Created by Cody Garvin on 6/10/21.
//

#if !os(Linux)

import Foundation

// MARK: - ObjC Compatibility

@objc(SEGAnalytics)
public class ObjCAnalytics: NSObject {
    internal let analytics: Analytics
    
    @objc
    public init(configuration: ObjCConfiguration) {
        self.analytics = Analytics(configuration: configuration.configuration)
    }
}

// MARK: - ObjC Events

@objc
extension ObjCAnalytics {
    @objc(track:)
    public func track(name: String) {
        track(name: name, properties: nil)
    }
    

    @objc(track:properties:)
    public func track(name: String, properties: [String: Any]?) {
        analytics.track(name: name, properties: properties)
    }

    /// Associate a user with their unique ID and record traits about them.
    /// - Parameters:
    ///   - userId: A database ID (or email address) for this user. If you don't have a userId
    ///     but want to record traits, you should pass nil. For more information on how we
    ///     generate the UUID and Apple's policies on IDs, see https://segment.io/libraries/ios#ids
    @objc(identify:)
    public func identify(userId: String) {
        identify(userId: userId, traits: nil)
    }

    /// Associate a user with their unique ID and record traits about them.
    /// - Parameters:
    ///   - userId: A database ID (or email address) for this user. If you don't have a userId
    ///     but want to record traits, you should pass nil. For more information on how we
    ///     generate the UUID and Apple's policies on IDs, see https://segment.io/libraries/ios#ids
    ///   - traits: A dictionary of traits you know about the user. Things like: email, name, plan, etc.
    @objc(identify:traits:)
    public func identify(userId: String, traits: [String: AnyHashable]?) {
        analytics.identify(userId: userId, traits: traits)
    }
    
    /// Track a screen change with a title, category and other properties.
    /// - Parameters:
    ///   - screenTitle: The title of the screen being tracked.
    @objc(screen:)
    public func screen(screenTitle: String) {
        screen(screenTitle: screenTitle, category: nil, properties: nil)
    }
    
    /// Track a screen change with a title, category and other properties.
    /// - Parameters:
    ///   - screenTitle: The title of the screen being tracked.
    ///   - category: A category to the type of screen if it applies.
    @objc(screen:category:)
    public func screen(screenTitle: String, category: String?) {
        analytics.screen(screenTitle: screenTitle, category: category, properties: nil)
    }
    /// Track a screen change with a title, category and other properties.
    /// - Parameters:
    ///   - screenTitle: The title of the screen being tracked.
    ///   - category: A category to the type of screen if it applies.
    ///   - properties: Any extra metadata associated with the screen. e.g. method of access, size, etc.
    @objc(screen:category:properties:)
    public func screen(screenTitle: String, category: String?, properties: [String: AnyHashable]?) {
        analytics.screen(screenTitle: screenTitle, category: category, properties: properties)
    }

    /// Associate a user with a group such as a company, organization, project, etc.
    /// - Parameters:
    ///   - groupId: A unique identifier for the group identification in your system.
    @objc(group:)
    public func group(groupId: String) {
        group(groupId: groupId, traits: nil)
    }

    /// Associate a user with a group such as a company, organization, project, etc.
    /// - Parameters:
    ///   - groupId: A unique identifier for the group identification in your system.
    ///   - traits: Traits of the group you may be interested in such as email, phone or name.
    @objc(group:traits:)
    public func group(groupId: String, traits: [String: AnyHashable]?) {
        analytics.group(groupId: groupId, traits: traits)
    }
}

// MARK: - ObjC Peripheral Functionality

@objc
extension ObjCAnalytics {
    @objc
    public var anonymousId: String {
        return analytics.anonymousId
    }
    
    @objc
    public var userId: String? {
        return analytics.userId
    }
    
    @objc
    public func traits() -> [String: Any]? {
        var traits: [String: Any]? = nil
        if let userInfo: UserInfo = analytics.store.currentState() {
            traits = userInfo.traits?.dictionaryValue
        }
        return traits
    }
    
    @objc
    public func flush() {
        analytics.flush()
    }
    
    @objc
    public func reset() {
        analytics.reset()
    }
    
    @objc
    public func settings() -> [String: Any]? {
        var result: [String: Any]? = nil
        if let system: System = analytics.store.currentState() {
            do {
                let encoder = JSONEncoder()
                let json = try encoder.encode(system.settings)
                if let r = try JSONSerialization.jsonObject(with: json) as? [String: Any] {
                    result = r
                }
            } catch {
                // not sure why this would fail, but report it.
                exceptionFailure("Failed to convert Settings to ObjC dictionary: \(error)")
            }
        }
        return result
    }
    
    @objc
    public func version() -> String {
        return analytics.version()
    }
}

#endif
