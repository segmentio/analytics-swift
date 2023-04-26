//
//  Configuration.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

// MARK: - Internal Configuration

public class Configuration {
    internal struct Values {
        var writeKey: String
        var application: Any? = nil
        var trackApplicationLifecycleEvents: Bool = true
        var flushAt: Int = 20
        var flushInterval: TimeInterval = 30
        var defaultSettings: Settings? = nil
        var autoAddSegmentDestination: Bool = true
        var apiHost: String = HTTPClient.getDefaultAPIHost()
        var cdnHost: String = HTTPClient.getDefaultCDNHost()
        var requestFactory: ((URLRequest) -> URLRequest)? = nil
        var errorHandler: ((Error) -> Void)? = nil
        var flushPolicies: [FlushPolicy] = [CountBasedFlushPolicy(), IntervalBasedFlushPolicy()]
    }
    
    internal var values: Values

    /// Initialize a configuration object to pass along to an Analytics instance.
    /// 
    /// - Parameter writeKey: Your Segment write key value
    public init(writeKey: String) {
        self.values = Values(writeKey: writeKey)
        // enable segment destination by default
        var settings = Settings(writeKey: writeKey)
        settings.integrations = try? JSON([
            "Segment.io": true
        ])
        
        self.defaultSettings(settings)
    }
}


// MARK: - Analytics Configuration

public extension Configuration {
    
    /// Sets a reference to your application.  This can be useful in instances
    /// where referring back to your application is necessary, such as within plugins
    /// or async code.  The default value is `nil`.
    ///
    /// - Parameter value: A reference to your application.
    /// - Returns: The current Configuration.
    @discardableResult
    func application(_ value: Any?) -> Configuration {
        values.application = value
        return self
    }
    
    /// Opt-in/out of tracking lifecycle events.  The default value is `false`.
    ///
    /// - Parameter enabled: A bool value
    /// - Returns: The current Configuration.
    @discardableResult
    func trackApplicationLifecycleEvents(_ enabled: Bool) -> Configuration {
        values.trackApplicationLifecycleEvents = enabled
        return self
    }
    
    /// Set the number of events necessary to automatically flush. The default
    /// value is `20`.
    ///
    /// - Parameter count: Event count to trigger a flush.
    /// - Returns: The current Configuration.
    @discardableResult
    func flushAt(_ count: Int) -> Configuration {
        values.flushAt = count
        return self
    }
    
    /// Set a time interval (in seconds) by which to trigger an automatic flush.
    /// The default value is `30`.
    ///
    /// - Parameter interval: A time interval
    /// - Returns: The current Configuration.
    @discardableResult
    func flushInterval(_ interval: TimeInterval) -> Configuration {
        values.flushInterval = interval
        return self
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
    ///
    /// Example:
    /// ```
    /// let defaults = Settings.load(resource: "mySegmentSettings.json")
    /// let config = Configuration(writeKey: "1234").defaultSettings(defaults)
    /// ```
    ///
    /// - Parameter settings: 
    /// - Returns: The current Configuration.
    @discardableResult
    func defaultSettings(_ settings: Settings?) -> Configuration {
        values.defaultSettings = settings
        return self
    }
    
    /// Enable/Disable the automatic adding of Segment as a destination.
    /// This can be useful in instances such as Consent Management, or in device
    /// mode only setups.  The default value is `true`.
    ///
    /// - Parameter value: true/false
    /// - Returns: The current Configuration.
    @discardableResult
    func autoAddSegmentDestination(_ value: Bool) -> Configuration {
        values.autoAddSegmentDestination = value
        return self
    }
    
    /// Sets an alternative API host.  This is useful when a proxy is in use, or
    /// events need to be routed to certain locales at all times (such as the EU).
    /// The default value is `api.segment.io/v1`.
    ///
    /// - Parameter value: A string representing the desired API host.
    /// - Returns: The current Configuration.
    @discardableResult
    func apiHost(_ value: String) -> Configuration {
        values.apiHost = value
        return self
    }
    
    /// Sets an alternative CDN host for settings retrieval. This is useful when
    /// a proxy is in use, or settings need to be queried from certain locales at
    /// all times (such as the EU). The default value is `cdn-settings.segment.com/v1`.
    ///
    /// - Parameter value: A string representing the desired CDN host.
    /// - Returns: The current Configuration.
    @discardableResult
    func cdnHost(_ value: String) -> Configuration {
        values.cdnHost = value
        return self
    }
    
    /// Sets a block to be used when generating outgoing HTTP requests.  Useful in
    /// proxying, or adding additional header information for outbound traffic.
    ///
    /// - Parameter value: A block to call when requests are made.
    /// - Returns: The current Configuration.
    @discardableResult
    func requestFactory(_ value: @escaping (URLRequest) -> URLRequest) -> Configuration {
        values.requestFactory = value
        return self
    }
    
    /// Sets an error handler to be called when errors are encountered by the Segment
    /// library.  See `AnalyticsError` for a list of possible errors that can be
    /// encountered.
    ///
    /// - Parameter value: A block to be called when an error occurs.
    /// - Returns: The current Configuration.
    @discardableResult
    func errorHandler(_ value: @escaping (Error) -> Void) -> Configuration {
        values.errorHandler = value
        return self
    }
    
    @discardableResult
    func flushPolicies(_ policies: [FlushPolicy]) -> Configuration {
        values.flushPolicies = policies
        return self
    }
}

extension Analytics {
    func configuration<T>(valueFor: () -> T) -> T {
        return valueFor()
    }
}
