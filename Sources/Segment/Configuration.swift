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
    }
    
    internal var values: Values

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
    @discardableResult
    func application(_ value: Any?) -> Configuration {
        values.application = value
        return self
    }
    
    @discardableResult
    func trackApplicationLifecycleEvents(_ enabled: Bool) -> Configuration {
        values.trackApplicationLifecycleEvents = enabled
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
    func defaultSettings(_ settings: Settings) -> Configuration {
        values.defaultSettings = settings
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
    
    @discardableResult
    func requestFactory(_ value: @escaping (URLRequest) -> URLRequest) -> Configuration {
        values.requestFactory = value
        return self
    }
    
    @discardableResult
    func errorHandler(_ value: @escaping (Error) -> Void) -> Configuration {
        values.errorHandler = value
        return self
    }
}

extension Analytics {
    func configuration<T>(valueFor: () -> T) -> T {
        return valueFor()
    }
}
