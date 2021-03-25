//
//  Configuration.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation

public typealias AdvertisingIdCallback = () -> String?


// MARK: - Internal Configuration

public struct Configuration {
    internal struct Values {
        var writeKey: String
        var advertisingIdCallback: AdvertisingIdCallback? = nil
        var trackInAppPurchases: Bool = false
        var trackApplicationLifecycleEvents: Bool = true
        var trackDeeplinks: Bool = true
        var flushAt: Int = 20
        var flushInterval: TimeInterval = 30
        var maxQueueSize: Int = 1000
        var application: Any? = nil
        var defaultSettings: Settings? = nil
        var autoAddSegmentDestination: Bool = true
    }
    internal var values: Values

    public init(writeKey: String) {
        self.values = Values(writeKey: writeKey)
    }
}


// MARK: - Analytics Configuration

public extension Configuration {
    @discardableResult
    mutating func trackAdvertisingId(callback: @escaping AdvertisingIdCallback) -> Configuration {
        values.advertisingIdCallback = callback
        return self
    }
    
    @discardableResult
    mutating func trackInAppPurchases(_ enabled: Bool) -> Configuration {
        values.trackInAppPurchases = enabled
        return self
    }
    
    @discardableResult
    mutating func trackApplicationLifecycleEvents(_ enabled: Bool) -> Configuration {
        values.trackApplicationLifecycleEvents = enabled
        return self
    }
    
    @discardableResult
    mutating func trackDeeplinks(_ enabled: Bool) -> Configuration {
        values.trackDeeplinks = enabled
        return self
    }
    
    @discardableResult
    mutating func flushAt(_ count: Int) -> Configuration {
        values.flushAt = count
        return self
    }
    
    @discardableResult
    mutating func flushInterval(_ interval: TimeInterval) -> Configuration {
        values.flushInterval = interval
        return self
    }
    
    @discardableResult
    mutating func maxQueueSize(_ eventCount: Int) -> Configuration {
        values.maxQueueSize = eventCount
        return self
    }
    
    @discardableResult
    mutating func autoAddSegmentDestination(_ value: Bool) -> Configuration {
        values.autoAddSegmentDestination = value
        return self
    }
}

