//
//  ObjCConfiguration.swift
//  
//
//  Created by Brandon Sneed on 8/13/21.
//

#if !os(Linux)

import Foundation

@objc(SEGConfiguration)
public class ObjCConfiguration: NSObject {
    internal var configuration: Configuration
    
    /// Sets a reference to your application.  This can be useful in instances
    /// where referring back to your application is necessary, such as within plugins
    /// or async code.  The default value is `nil`.
    @objc
    public var application: Any? {
        get {
            return configuration.values.application
        }
        set(value) {
            configuration.application(value)
        }
    }
    
    /// Opt-in/out of tracking lifecycle events.  The default value is `false`.
    @objc
    public var trackApplicationLifecycleEvents: Bool {
        get {
            return configuration.values.trackApplicationLifecycleEvents
        }
        set(value) {
            configuration.trackApplicationLifecycleEvents(value)
        }
    }
    
    /// Set the number of events necessary to automatically flush. The default
    /// value is `20`.
    @objc
    public var flushAt: Int {
        get {
            return configuration.values.flushAt
        }
        set(value) {
            configuration.flushAt(value)
        }
    }
    
    /// Set a time interval (in seconds) by which to trigger an automatic flush.
    /// The default value is `30`.
    @objc
    public var flushInterval: TimeInterval {
        get {
            return configuration.values.flushInterval
        }
        set(value) {
            configuration.flushInterval(value)
        }
    }
    
    /// Sets a default set of Settings.  Normally these will come from Segment's
    /// api.segment.com/v1/projects/<writekey>/settings, however in instances such
    /// as first app launch, it can be useful to have a pre-set batch of settings to
    /// ensure that the proper destinations and other settings are enabled prior
    /// to receiving them from the Settings endpoint.  The default is `nil`.
    ///
    /// You can retrieve a copy of your settings from the following URL:
    ///
    /// https://cdn-settings.segment.com/v1/projects/<writekey>/settings
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
    
    /// Enable/Disable the automatic adding of Segment as a destination.
    /// This can be useful in instances such as Consent Management, or in device
    /// mode only setups.  The default value is `true`.
    @objc
    public var autoAddSegmentDestination: Bool {
        get {
            return configuration.values.autoAddSegmentDestination
        }
        set(value) {
            configuration.autoAddSegmentDestination(value)
        }
    }
    
    /// Sets an alternative API host.  This is useful when a proxy is in use, or
    /// events need to be routed to certain locales at all times (such as the EU).
    /// The default value is `api.segment.io/v1`.
    @objc
    public var apiHost: String {
        get {
            return configuration.values.apiHost
        }
        set(value) {
            configuration.apiHost(value)
        }
    }

    /// Sets an alternative CDN host for settings retrieval. This is useful when
    /// a proxy is in use, or settings need to be queried from certain locales at
    /// all times (such as the EU). The default value is `cdn-settings.segment.com/v1`.
    @objc
    public var cdnHost: String {
        get {
            return configuration.values.cdnHost
        }
        set(value) {
            configuration.cdnHost(value)
        }
    }
    
    /// Sets a block to be used when generating outgoing HTTP requests.  Useful in
    /// proxying, or adding additional header information for outbound traffic.
    ///
    /// - Parameter value: A block to call when requests are made.
    /// - Returns: The current Configuration.
    @objc
    public var requestFactory: ((URLRequest) -> URLRequest)? {
        get {
            return configuration.values.requestFactory
        }
        set(value) {
            configuration.values.requestFactory = value
        }
    }

    /// Initialize a configuration object to pass along to an Analytics instance.
    ///
    /// - Parameter writeKey: Your Segment write key value
    @objc
    public init(writeKey: String) {
        self.configuration = Configuration(writeKey: writeKey)
    }
}

#endif

