//
//  Configuration.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation
import JSONSafeEncoder
#if os(Linux)
import FoundationNetworking
#endif

// MARK: - Custom AnonymousId generator
/// Conform to this protocol to generate your own AnonymousID
public protocol AnonymousIdGenerator: AnyObject, Codable {
    /// Returns a new anonymousId.  Segment still manages storage and retrieval of the
    /// current anonymousId and will call this method when new id's are needed.
    ///
    /// - Returns: A new anonymousId.
    func newAnonymousId() -> String
}

// MARK: - Operating Mode
/// Specifies the operating mode/context
public enum OperatingMode {
    /// The operation of the Analytics client are synchronous.
    case synchronous
    /// The operation of the Analytics client are asynchronous.
    case asynchronous
    
    static internal let defaultQueue = DispatchQueue(label: "com.segment.operatingModeQueue", qos: .utility)
}

// MARK: - Storage Mode
/// Specifies the storage mode to be used for events
public enum StorageMode {
    /// Store events to disk (default).
    case disk
    /// Store events to disk in the given a directory URL.
    case diskAtURL(URL)
    /// Store events to memory and specify a max count before they roll off.
    case memory(Int)
    /// Some custom, user-defined storage mechanism conforming to `DataStore`.
    case custom(any DataStore)
}

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
        var operatingMode: OperatingMode = .asynchronous
        var flushQueue: DispatchQueue = OperatingMode.defaultQueue
        var userAgent: String? = nil
        var jsonNonConformingNumberStrategy: JSONSafeEncoder.NonConformingFloatEncodingStrategy = .zero
        var storageMode: StorageMode = .disk
        var anonymousIdGenerator: AnonymousIdGenerator = SegmentAnonymousId()
    }
    
    internal var values: Values

    /// Initialize a configuration object to pass along to an Analytics instance.
    ///
    /// - Parameter writeKey: Your Segment write key value
    public init(writeKey: String) {
        self.values = Values(writeKey: writeKey)
        JSON.jsonNonConformingNumberStrategy = self.values.jsonNonConformingNumberStrategy
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
    
    /// Informs the Analytics instance of its operating mode/context.
    /// Use `.server` when operating in a web service, or when synchronous operation
    /// is desired.  Use `.client` when operating in a long lived process,
    /// desktop/mobile application.
    @discardableResult
    func operatingMode(_ mode: OperatingMode) -> Configuration {
        values.operatingMode = mode
        return self
    }
    
    /// Specify a custom queue to use when performing a flush operation.  The default
    /// value is a Segment owned background queue.
    @discardableResult
    func flushQueue(_ queue: DispatchQueue) -> Configuration {
        values.flushQueue = queue
        return self
    }

    /// Specify a custom UserAgent string.  This bypasses the OS dependent check entirely.
    @discardableResult
    func userAgent(_ userAgent: String) -> Configuration {
        values.userAgent = userAgent
        return self
    }
    
    /// This option specifies how NaN/Infinity are handled when encoding JSON.
    /// The default is .zero.  See JSONSafeEncoder.NonConformingFloatEncodingStrategy for more informatino.
    @discardableResult
    func jsonNonConformingNumberStrategy(_ strategy: JSONSafeEncoder.NonConformingFloatEncodingStrategy) -> Configuration {
        values.jsonNonConformingNumberStrategy = strategy
        JSON.jsonNonConformingNumberStrategy = values.jsonNonConformingNumberStrategy
        return self
    }
    
    /// Specify the storage mode to use.  The default is `.disk`.
    @discardableResult
    func storageMode(_ mode: StorageMode) -> Configuration {
        values.storageMode = mode
        return self
    }
    
    /// Specify a custom anonymousId generator.  The default is and instance of `SegmentAnonymousId`.
    @discardableResult
    func anonymousIdGenerator(_ generator: AnonymousIdGenerator) -> Configuration {
        values.anonymousIdGenerator = generator
        return self
    }
}

extension Analytics {
    func configuration<T>(valueFor: () -> T) -> T {
        return valueFor()
    }
}
