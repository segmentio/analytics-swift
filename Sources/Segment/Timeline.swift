//
//  Timeline.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran


// MARK: - Main Timeline

public class Timeline {
    internal let plugins: [PluginType: Mediator]
    
    public init() {
        self.plugins = [
            .before: Mediator(),
            .enrichment: Mediator(),
            .destination: Mediator(),
            .after: Mediator(),
            .utility: Mediator()
        ]
    }
    
    @discardableResult
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

internal class Mediator {
    internal func add(plugin: Plugin) {
        plugins.append(plugin)
        if let settings = plugin.analytics?.settings() {
            plugin.update(settings: settings, type: .initial)
        }
    }
    
    internal func remove(plugin: Plugin) {
        plugins.removeAll { (storedPlugin) -> Bool in
            return plugin === storedPlugin
        }
    }

    internal var plugins = [Plugin]()
    internal func execute<T: RawEvent>(event: T) -> T? {
        var result: T? = event
        
        plugins.forEach { (plugin) in
            if let r = result {
                // Drop the event return because we don't care about the
                // final result.
                if plugin is DestinationPlugin {
                    _ = plugin.execute(event: r)
                } else {
                    result = plugin.execute(event: r)
                }
            }
        }
        
        return result
    }
}


// MARK: - Plugin Support

extension Timeline {
    internal func apply(_ closure: (Plugin) -> Void) {
        for type in PluginType.allCases {
            if let mediator = plugins[type] {
                mediator.plugins.forEach { (plugin) in
                    closure(plugin)
                    if let destPlugin = plugin as? DestinationPlugin {
                        destPlugin.apply(closure: closure)
                    }
                }
            }
        }
    }
    
    internal func add(plugin: Plugin) {
        if let mediator = plugins[plugin.type] {
            mediator.add(plugin: plugin)
        }
    }
    
    internal func remove(plugin: Plugin) {
        // remove all plugins with this name in every category
        for type in PluginType.allCases {
            if let mediator = plugins[type] {
                let toRemove = mediator.plugins.filter { (storedPlugin) -> Bool in
                    return plugin === storedPlugin
                }
                toRemove.forEach { (plugin) in
                    plugin.shutdown()
                    mediator.remove(plugin: plugin)
                }
            }
        }
    }
    
    internal func find<T: Plugin>(pluginType: T.Type) -> T? {
        var found = [Plugin]()
        for type in PluginType.allCases {
            if let mediator = plugins[type] {
                found.append(contentsOf: mediator.plugins.filter { (plugin) -> Bool in
                    return plugin is T
                })
            }
        }
        return found.first as? T
    }
    
    internal func find(key: String) -> DestinationPlugin? {
        var found = [Plugin]()
        if let mediator = plugins[.destination] {
            found.append(contentsOf: mediator.plugins.filter{ plugin in
                guard let p = plugin as? DestinationPlugin else { return false }
                return p.key == key
            })
        }
        return found.first as? DestinationPlugin
    }
}

// MARK: - Plugin Timeline Execution

extension Plugin {
    public func execute<T: RawEvent>(event: T?) -> T? {
        // do nothing.
        return event
    }
    
    public func update(settings: Settings, type: UpdateType) {
        // do nothing by default, user can override.
    }

    public func shutdown() {
        // do nothing by default, user can override.
    }
}

extension EventPlugin {
    public func execute<T: RawEvent>(event: T?) -> T? {
        var result: T? = event
        switch result {
            case let r as IdentifyEvent:
                result = self.identify(event: r) as? T
            case let r as TrackEvent:
                result = self.track(event: r) as? T
            case let r as ScreenEvent:
                result = self.screen(event: r) as? T
            case let r as AliasEvent:
                result = self.alias(event: r) as? T
            case let r as GroupEvent:
                result = self.group(event: r) as? T
            default:
                break
        }
        return result
    }

    // Default implementations that forward the event. This gives plugin
    // implementors the chance to interject on an event.
    public func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
    
    public func track(event: TrackEvent) -> TrackEvent? {
        return event
    }
    
    public func screen(event: ScreenEvent) -> ScreenEvent? {
        return event
    }
    
    public func group(event: GroupEvent) -> GroupEvent? {
        return event
    }
    
    public func alias(event: AliasEvent) -> AliasEvent? {
        return event
    }
    
    public func flush() { }
    public func reset() { }
}

// MARK: - Destination Timeline

extension DestinationPlugin {
    public func execute<T: RawEvent>(event: T?) -> T? {
        var result: T? = event
        if let r = result {
            result = self.process(incomingEvent: r)
        }
        return result
    }
    
    internal func isDestinationEnabled(event: RawEvent) -> Bool {
        var customerDisabled = false
        if let disabled: Bool = event.integrations?.value(forKeyPath: KeyPath(self.key)), disabled == false {
            customerDisabled = true
        }
        
        var hasSettings = false
        if let settings = analytics?.settings() {
            hasSettings = settings.hasIntegrationSettings(forPlugin: self)
        }
        
        return (hasSettings == true && customerDisabled == false)
    }

    internal func process<E: RawEvent>(incomingEvent: E) -> E? {
        // This will process plugins (think destination middleware) that are tied
        // to this destination.
        
        var result: E? = nil
        
        if isDestinationEnabled(event: incomingEvent) {
            // apply .before and .enrichment types first ...
            let beforeResult = timeline.applyPlugins(type: .before, event: incomingEvent)
            let enrichmentResult = timeline.applyPlugins(type: .enrichment, event: beforeResult)
            
            // now we execute any overrides we may have made.  basically, the idea is to take an
            // incoming event, like identify, and map it to whatever is appropriate for this destination.
            var destinationResult: E? = nil
            switch enrichmentResult {
                case let e as IdentifyEvent:
                    destinationResult = identify(event: e) as? E
                case let e as TrackEvent:
                    destinationResult = track(event: e) as? E
                case let e as ScreenEvent:
                    destinationResult = screen(event: e) as? E
                case let e as GroupEvent:
                    destinationResult = group(event: e) as? E
                case let e as AliasEvent:
                    destinationResult = alias(event: e) as? E
                default:
                    break
            }
            
            // apply .after plugins ...
            result = timeline.applyPlugins(type: .after, event: destinationResult)
        }
        
        return result
    }
}

