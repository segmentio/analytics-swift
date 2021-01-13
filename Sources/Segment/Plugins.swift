//
//  Plugins.swift
//  Segment
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

public struct Plugins {
    internal let timeline = Timeline()
    
    public init() {
        
    }
    
    /**
     Applies the supplied closure to the currently loaded set of plugins.
     NOTE: This does not apply to plugins contained within DestinationPlugins.
     
     - Parameter closure: A closure that takes an plugin to be operated on as a parameter.
     
     */
    public func apply(_ closure: (Plugin) -> Void) {
        timeline.applyToPlugins(closure)
    }
    
    /**
     Adds a new plugin to the currently loaded set.
     
     - Parameter plugin: The plugin to be added.
     - Returns: Returns the name of the supplied plugin.
     
     */
    @discardableResult
    public func add(_ plugin: Plugin) -> String {
        timeline.add(plugin: plugin)
        return plugin.name
    }
    
    /**
     Removes and unloads plugins with a matching name from the system.
     
     - Parameter pluginName: An plugin name.
     */
    public func remove(_ pluginName: String) {
        timeline.remove(pluginName: pluginName)
    }
    
    /*
    private func fetchSettings() {
        
        // TODO: Grab the previous cached settings
        
        guard let writeKey = analytics?.configuration.writeKey else { return }
        
        httpClient.settingsFor(write: writeKey) { (success, settings) in
            if success {
                // TODO: Overwrite cached settings
            } else {
                // TODO: Get default settings to work from
            }
            
            print("Settings: \(settings.printPretty())")
            // TODO: Cache the settings
        }
    }*/
}

/**
 PluginType specifies where in the chain a given plugin is to be executed.
 */
public enum PluginType: Int, CaseIterable {
    /// Executed before event processing begins.
    case before
    /// Executed as the first level of event processing.
    case enrichment
    /// Executed as events begin to pass off to destinations.
    case destination
    /// Executed after all event processing is completed.  This can be used to perform cleanup operations, etc.
    case after
    /// Executed only when called manually, such as Logging.
    case utility
}

public protocol Plugin: AnyObject {
    var type: PluginType { get }
    var name: String { get }
    var analytics: Analytics { get }
    
    init(name: String, analytics: Analytics)
    func execute<T: RawEvent>(event: T?, settings: Settings?) -> T?
    func shutdown()
}

public protocol EventPlugin: Plugin {
    func identify(event: IdentifyEvent) -> IdentifyEvent?
    func track(event: TrackEvent) -> TrackEvent?
    func group(event: GroupEvent) -> GroupEvent?
    func alias(event: AliasEvent) -> AliasEvent?
    func screen(event: ScreenEvent) -> ScreenEvent?
}

public protocol DestinationPlugin: EventPlugin {
    var plugins: Plugins { get set }
}

public protocol UtilityPlugin: EventPlugin { }

// For internal platform-specific bits
internal protocol PlatformPlugin: Plugin {
    static var specificName: String { get set }
}


// MARK: - Plugin Default Implementations

extension Plugin {
    public func execute<T: RawEvent>(event: T?, settings: Settings?) -> T? {
        // do nothing.
        return event
    }

    public func shutdown() {
        // do nothing by default, user can override.
    }
}

extension EventPlugin {
    func execute<T: RawEvent>(event: T?, settings: Settings?) -> T? {
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
                print("something is screwed up")
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
}

extension DestinationPlugin {
    func execute<T: RawEvent>(event: T?, settings: Settings?) -> T? {
        var result: T? = event
        if let r = result {
            result = self.process(incomingEvent: r)
        }
        return result
    }

    internal func process<E: RawEvent>(incomingEvent: E) -> E? {
        // This will process plugins (think destination middleware) that are tied
        // to this destination.
        
        // apply .before and .enrichment types first ...
        let beforeResult = plugins.timeline.applyPlugins(type: .before, event: incomingEvent)
        let enrichmentResult = plugins.timeline.applyPlugins(type: .enrichment, event: beforeResult)
        
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
                print("something is screwed up")
        }
        
        // apply .after plugins ...
        let afterResult = plugins.timeline.applyPlugins(type: .after, event: destinationResult)

        // DEBUG
        print("Destination (\(name)): \(afterResult?.prettyPrint() ?? "")")
        // DEBUG
        
        return afterResult
    }
}

