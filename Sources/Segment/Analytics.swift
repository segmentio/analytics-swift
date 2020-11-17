//
//  Analytics.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

public class Analytics {
    internal var configuration: Configuration
    
    init(writeKey: String) {
        configuration = Configuration(writeKey: writeKey)
    }
    
    init(config: Configuration) {
        configuration = config
    }
    
    func build() -> Analytics {
        return Analytics(config: configuration)
    }
}
