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

public enum UpdateType {
    case initial
    case refresh
}

public protocol Plugin: AnyObject {
    var type: PluginType { get }
    var analytics: Analytics? { get set }
    
    func configure(analytics: Analytics)
    func update(settings: Settings, type: UpdateType)
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
    var key: String { get }
    var timeline: Timeline { get }
    func add(plugin: Plugin) -> Plugin
    func apply(closure: (Plugin) -> Void)
    func remove(plugin: Plugin)
}

public protocol UtilityPlugin: EventPlugin { }

public protocol VersionedPlugin {
    static func version() -> String
}

// For internal platform-specific bits
internal protocol PlatformPlugin: Plugin { }


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
    public func add(plugin: Plugin) -> Plugin {
        if let analytics = self.analytics {
            plugin.configure(analytics: analytics)
        }
        timeline.add(plugin: plugin)
        return plugin
    }
    
    /**
     Removes and unloads plugins with a matching name from the system.
     
     - Parameter pluginName: An plugin name.
     */
    public func remove(plugin: Plugin) {
        timeline.remove(plugin: plugin)
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
    public func add(plugin: Plugin) -> Plugin {
        plugin.configure(analytics: self)
        timeline.add(plugin: plugin)
        return plugin
    }
    
    /**
     Removes and unloads plugins with a matching name from the system.
     
     - Parameter pluginName: An plugin name.
     */
    public func remove(plugin: Plugin) {
        timeline.remove(plugin: plugin)
    }
    
    public func find<T: Plugin>(pluginType: T.Type) -> T? {
        return timeline.find(pluginType: pluginType)
    }
    
    public func find(key: String) -> DestinationPlugin? {
        return timeline.find(key: key)
    }
}
