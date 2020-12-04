//
//  Configuration.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation

public typealias AdvertisingIdCallback = () -> String?

//protocol SegmentApplication: UIApplication {
//    
//}

internal struct Configuration {
    var writeKey: String
    var startDisabled: Bool = false
    var advertisingIdCallback: AdvertisingIdCallback? = nil
    var trackInAppPurchases: Bool = false
    var trackApplicationLifecycleEvents: Bool = true
    var trackDeeplinks: Bool = true
    var flushAt: Int = 20
    var flushInterval: TimeInterval = 30
    var maxQueueSize: Int = 1000
    var application: Any? = nil
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
    func trackInAppPurchases(_ enabled: Bool) -> Analytics {
        configuration.trackInAppPurchases = enabled
        return self
    }
    
    @discardableResult
    func trackApplicationLifecycleEvents(_ enabled: Bool) -> Analytics {
        configuration.trackApplicationLifecycleEvents = enabled
        return self
    }
    
    @discardableResult
    func trackDeeplinks(_ enabled: Bool) -> Analytics {
        configuration.trackDeeplinks = enabled
        return self
    }
    
    @discardableResult
    func flushAt(_ count: Int) -> Analytics {
        configuration.flushAt = count
        return self
    }
    
    @discardableResult
    func flushInterval(_ interval: TimeInterval) -> Analytics {
        configuration.flushInterval = interval
        return self
    }
    
    @discardableResult
    func maxQueueSize(_ eventCount: Int) -> Analytics {
        configuration.maxQueueSize = eventCount
        return self
    }

}

// Deprecated
extension Configuration {
    
//    class UIBackgroundTaskIdentifier { }
//    func seg_beginBackgroundTaskWithName(taskName: String?, expirationHandler: () -> (Void)) -> UIBackgroundTaskIdentifier {
//        return UIBackgroundTaskIdentifier()
//    }
//
//    func seg_endBackgroundTask(identifier: UIBackgroundTaskIdentifier) {
//        // ...
//    }
    
    
}
