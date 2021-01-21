//
//  Timeline.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran


public class Timeline: Subscriber {
    internal let plugins: [PluginType: Mediator]
    
    public init() {
        self.plugins = [
            .before: Mediator(),
            .enrichment: Mediator(),
            .destination: Mediator(),
            .after: Mediator(),
            .utility: Mediator()
        ]
                
//        store.subscribe(self, handler: systemUpdate)
    }
    
    internal func process<E: RawEvent>(incomingEvent: E) -> E? {
        // apply .before and .enrichment types first ...
        let beforeResult = applyPlugins(type: .before, event: incomingEvent)
        // .enrichment here is akin to source middleware in the old analytics-ios.
        let enrichmentResult = applyPlugins(type: .enrichment, event: beforeResult)
        
        // once the event enters a destination, we don't want
        // to know about changes that happen there. those changes
        // are to only be received by the destination.
        _ = applyPlugins(type: .destination, event: enrichmentResult)
        
        // apply .after plugins ...
        let afterResult = applyPlugins(type: .after, event: enrichmentResult)

        // DEBUG
        print("System Results: \(afterResult?.prettyPrint() ?? "")")
        // DEBUG
        
        return afterResult
    }
    
    // helper method used by DestinationPlugins and Timeline
    internal func applyPlugins<E: RawEvent>(type: PluginType, event: E?) -> E? {
        var result: E? = event
        if let mediator = plugins[type], let e = event {
            result = mediator.execute(event: e)
        }
        return result
    }
}


// MARK: - Plugin Support

/**
 This suite of functions supplies core functionality back up to the public
 `Plugin` type.
 */
extension Timeline {
    internal func applyToPlugins(_ closure: (Plugin) -> Void) {
        for type in PluginType.allCases {
            if let mediator = plugins[type] {
                mediator.plugins.forEach { (plugin) in
                    closure(plugin)
                }
            }
        }
    }
    
    internal func add(plugin: Plugin) {
        if let mediator = plugins[plugin.type] {
            mediator.add(plugin: plugin)
        }
    }
    
    internal func remove(pluginName: String) {
        // remove all plugins with this name in every category
        for type in PluginType.allCases {
            if let mediator = plugins[type] {
                let toRemove = mediator.plugins.filter { (plugin) -> Bool in
                    return plugin.name == pluginName
                }
                toRemove.forEach { (plugin) in
                    plugin.shutdown()
                    mediator.remove(pluginName: pluginName)
                }
            }
        }
    }

}
