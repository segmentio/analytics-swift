//
//  Configuration.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation

public typealias AdvertisingIdCallback = () -> String?

internal struct Configuration {
    var writeKey: String
    var startDisabled: Bool = false
    var advertisingIdCallback: AdvertisingIdCallback? = nil
    var trackInAppPurchases: Bool = false
    var trackApplicationLifecycleEvents: Bool = true
    var trackDeeplinks: Bool = true
    var flushAt: Int = 20
    var flushInterval: Int = 30
}

public extension Analytics {
    @discardableResult
    func startDisabled() -> Analytics {
        configuration.startDisabled = true
        return self
    }
    
    @discardableResult
    func trackAdvertisingId(callback: @escaping AdvertisingIdCallback) -> Analytics {
        configuration.advertisingIdCallback = callback
        return self
    }
    
    @discardableResult
    func trackInAppPurchases(enabled: Bool) -> Analytics {
        configuration.trackInAppPurchases = enabled
        return self
    }
    
    @discardableResult
    func trackApplicationLifecycleEvents(enabled: Bool) -> Analytics {
        configuration.trackApplicationLifecycleEvents = enabled
        return self
    }
    
    @discardableResult
    func trackDeeplinks(enabled: Bool) -> Analytics {
        configuration.trackDeeplinks = enabled
        return self
    }
}
