//
//  Mediator.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

internal class Mediator {
    internal func add(plugin: Plugin) {
        plugins.append(plugin)
    }
    
    internal func remove(pluginName: String) {
        plugins.removeAll { (plugin) -> Bool in
            return plugin.name == pluginName
        }
    }

    internal var plugins = [Plugin]()
    internal func execute<T: RawEvent>(event: T) -> T? {
        var result: T? = event
        
        plugins.forEach { (plugin) in
            if let r = result {
                result = plugin.execute(event: r, settings: nil)
            }
        }
        
        return result
    }
}
