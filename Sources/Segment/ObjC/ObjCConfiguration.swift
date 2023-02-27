//
//  File.swift
//  
//
//  Created by Brandon Sneed on 8/13/21.
//

#if !os(Linux)

import Foundation

@objc(SEGConfiguration)
public class ObjCConfiguration: NSObject {
    internal var configuration: Configuration
    
    @objc
    public var application: Any? {
        get {
            return configuration.values.application
        }
        set(value) {
            configuration.application(value)
        }
    }
    
    @objc
    public var trackApplicationLifecycleEvents: Bool {
        get {
            return configuration.values.trackApplicationLifecycleEvents
        }
        set(value) {
            configuration.trackApplicationLifecycleEvents(value)
        }
    }
    
    @objc
    public var flushAt: Int {
        get {
            return configuration.values.flushAt
        }
        set(value) {
            configuration.flushAt(value)
        }
    }
    
    @objc
    public var flushInterval: TimeInterval {
        get {
            return configuration.values.flushInterval
        }
        set(value) {
            configuration.flushInterval(value)
        }
    }
    
    @objc
    public var defaultSettings: [String: Any] {
        get {
            var result = [String: Any]()
            do {
                let encoder = JSONEncoder()
                let json = try encoder.encode(configuration.values.defaultSettings)
                if let r = try JSONSerialization.jsonObject(with: json) as? [String: Any] {
                    result = r
                }
            } catch {
                // not sure why this would fail, but report it.
                exceptionFailure("Failed to convert Settings to ObjC dictionary: \(error)")
            }
            return result
        }
        set(value) {
            do {
                let json = try JSONSerialization.data(withJSONObject: value, options: .prettyPrinted)
                let decoder = JSONDecoder()
                let settings = try decoder.decode(Settings.self, from: json)
                configuration.defaultSettings(settings)
            } catch {
                exceptionFailure("Failed to convert defaultSettings to Settings object: \(error)")
            }
        }
    }
    
    @objc
    public var autoAddSegmentDestination: Bool {
        get {
            return configuration.values.autoAddSegmentDestination
        }
        set(value) {
            configuration.autoAddSegmentDestination(value)
        }
    }
    
    @objc
    public var apiHost: String {
        get {
            return configuration.values.apiHost
        }
        set(value) {
            configuration.apiHost(value)
        }
    }

    @objc
    public var cdnHost: String {
        get {
            return configuration.values.cdnHost
        }
        set(value) {
            configuration.cdnHost(value)
        }
    }


    @objc
    public init(writeKey: String) {
        self.configuration = Configuration(writeKey: writeKey)
    }
}

#endif

