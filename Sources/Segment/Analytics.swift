//
//  Analytics.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

typealias Properties = Codable
typealias Integrations = [String: Codable]

protocol EdgeFunctionMiddleware {
    // This is a stub
}

public class Analytics {
    internal var configuration: Configuration
    
    var isEnabled = true
    
    init(writeKey: String) {
        configuration = Configuration(writeKey: writeKey)
    }
    
    internal init(config: Configuration) {
        configuration = config
    }
    
    func build() -> Analytics {
        return Analytics(config: configuration)
    }
}

extension Analytics {
    
    func flush() {
        // ...
    }
    
    func reset() {
        // ...
    }
    
    func version() -> Int {
        // ...
        return 0
    }
    
    func anonymousId() -> String {
        // ??? not getAnonymousId
        return ""
    }
    
    func deviceToken() -> String {
        // ??? not getDeviceToken
        return ""
    }
    
    func edgeFunction() -> EdgeFunctionMiddleware? {
        return nil
    }
}

extension Analytics {
    @available(*, deprecated)
    func enable() {
        
    }
    
    @available(*, deprecated)
    func disable() {
        
    }
}
