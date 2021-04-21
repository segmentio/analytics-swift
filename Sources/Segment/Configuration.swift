//
//  Configuration.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation

public typealias AdvertisingIdCallback = () -> String?


// MARK: - Internal Configuration

// - IDFA handled by external plugin if desired.
// - recordingScreenViews handled by plugin?
// - trackInAppPurchases handled by plugin?
// - trackDeepLinks ??
// - flushAt / flushInterval to be done by segment destination plugin

public class Configuration {
    internal struct Values {
        var writeKey: String
        var application: Any? = nil
        var trackInAppPurchases: Bool = false
        var trackApplicationLifecycleEvents: Bool = true
        var trackDeeplinks: Bool = true
        var flushAt: Int = 20
        var flushInterval: TimeInterval = 30
        var defaultSettings: Settings? = nil
        var autoAddSegmentDestination: Bool = true
        var apiHost: String = HTTPClient.getDefaultAPIHost()
        var cdnHost: String = HTTPClient.getDefaultCDNHost()
    }
    internal var values: Values

    public init(writeKey: String) {
        self.values = Values(writeKey: writeKey)
    }
}


// MARK: - Analytics Configuration

public extension Configuration {
    @discardableResult
    func trackInAppPurchases(_ enabled: Bool) -> Configuration {
        values.trackInAppPurchases = enabled
        return self
    }
    
    @discardableResult
    func trackApplicationLifecycleEvents(_ enabled: Bool) -> Configuration {
        values.trackApplicationLifecycleEvents = enabled
        return self
    }
    
    @discardableResult
    func trackDeeplinks(_ enabled: Bool) -> Configuration {
        values.trackDeeplinks = enabled
        return self
    }
    
    @discardableResult
    func flushAt(_ count: Int) -> Configuration {
        values.flushAt = count
        return self
    }
    
    @discardableResult
    func flushInterval(_ interval: TimeInterval) -> Configuration {
        values.flushInterval = interval
        return self
    }
    
    @discardableResult
    func autoAddSegmentDestination(_ value: Bool) -> Configuration {
        values.autoAddSegmentDestination = value
        return self
    }
    
    @discardableResult
    func apiHost(_ value: String) -> Configuration {
        values.apiHost = value
        return self
    }
    
    @discardableResult
    func cdnHost(_ value: String) -> Configuration {
        values.cdnHost = value
        return self
    }
}

