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
    var advertisingIdCallback: AdvertisingIdCallback? = nil
    var trackInAppPurchases: Bool = false
}

public extension Analytics {
    @discardableResult
    func trackAdvertisingId(callback: @escaping AdvertisingIdCallback) -> Analytics {
        configuration.advertisingIdCallback = callback
        return self
    }
    
    @discardableResult
    func trackInAppPurchases(enabled: Bool) -> Analytics {
        configuration.trackInAppPurchases = true
        return self
    }
}
