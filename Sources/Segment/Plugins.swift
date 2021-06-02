//
//  Plugins.swift
//  Segment
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

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
    var analytics: Analytics? { get set }
    
    init(name: String)
    func configure(analytics: Analytics)
    func update(settings: Settings)
    func execute<T: RawEvent>(event: T?) -> T?
    func shutdown()
}

public protocol EventPlugin: Plugin {
    func identify(event: IdentifyEvent) -> IdentifyEvent?
    func track(event: TrackEvent) -> TrackEvent?
    func group(event: GroupEvent) -> GroupEvent?
    func alias(event: AliasEvent) -> AliasEvent?
    func screen(event: ScreenEvent) -> ScreenEvent?
    func reset()
    func flush()
}

public protocol DestinationPlugin: EventPlugin {
    var timeline: Timeline { get }
    func add(plugin: Plugin) -> String
    func apply(closure: (Plugin) -> Void)
    func remove(pluginName: String)
}

public protocol UtilityPlugin: EventPlugin { }

// For internal platform-specific bits
internal protocol PlatformPlugin: Plugin {
    static var specificName: String { get set }
}

extension PlatformPlugin {
    internal init() {
        self.init(name: Self.specificName)
    }
}

// MARK: - Plugin instance helpers
extension Plugin {
    public func configure(analytics: Analytics) {
        self.analytics = analytics
    }
}


// MARK: - Adding/Removing Plugins

extension DestinationPlugin {
    public func configure(analytics: Analytics) {
        self.analytics = analytics
        apply { plugin in
            plugin.configure(analytics: analytics)
        }
    }
    
    /**
     Applies the supplied closure to the currently loaded set of plugins.
     
     - Parameter closure: A closure that takes an plugin to be operated on as a parameter.
     
     */
    public func apply(closure: (Plugin) -> Void) {
        timeline.apply(closure)
    }
    
    /**
     Adds a new plugin to the currently loaded set.
     
     - Parameter plugin: The plugin to be added.
     - Returns: Returns the name of the supplied plugin.
     
     */
    @discardableResult
    public func add(plugin: Plugin) -> String {
        if let analytics = self.analytics {
            plugin.configure(analytics: analytics)
        }
        timeline.add(plugin: plugin)
        return plugin.name
    }
    
    /**
     Removes and unloads plugins with a matching name from the system.
     
     - Parameter pluginName: An plugin name.
     */
    public func remove(pluginName: String) {
        timeline.remove(pluginName: pluginName)
    }

}

extension Analytics {
    /**
     Applies the supplied closure to the currently loaded set of plugins.
     NOTE: This does not apply to plugins contained within DestinationPlugins.
     
     - Parameter closure: A closure that takes an plugin to be operated on as a parameter.
     
     */
    public func apply(closure: (Plugin) -> Void) {
        timeline.apply(closure)
    }
    
    /**
     Adds a new plugin to the currently loaded set.
     
     - Parameter plugin: The plugin to be added.
     - Returns: Returns the name of the supplied plugin.
     
     */
    @discardableResult
    public func add(plugin: Plugin) -> String {
        plugin.configure(analytics: self)
        timeline.add(plugin: plugin)
        if plugin is DestinationPlugin && !(plugin is SegmentDestination) {
            store.dispatch(action: System.AddIntegrationAction(pluginName: plugin.name))
        }
        return plugin.name
    }
    
    /**
     Removes and unloads plugins with a matching name from the system.
     
     - Parameter pluginName: An plugin name.
     */
    public func remove(pluginName: String) {
        timeline.remove(pluginName: pluginName)
        store.dispatch(action: System.RemoveIntegrationAction(pluginName: pluginName))
    }
    
    public func find(pluginName: String) -> Plugin? {
        return timeline.find(pluginName: pluginName)
    }
}
