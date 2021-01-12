//
//  Extensions.swift
//  Segment
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

public struct Extensions {
    internal let timeline = Timeline()
    
    public init() {
        
    }
    
    /**
     Applies the supplied closure to the currently loaded set of extensions.
     NOTE: This does not apply to extensions contained within DestinationExtensions.
     
     - Parameter closure: A closure that takes an extension to be operated on as a parameter.
     
     */
    public func apply(_ closure: (Extension) -> Void) {
        timeline.applyToExtensions(closure)
    }
    
    /**
     Adds a new extension to the currently loaded set.
     
     - Parameter extension: The extension to be added.
     - Returns: Returns the name of the supplied extension.
     
     */
    @discardableResult
    public func add(_ extension: Extension) -> String {
        timeline.add(extension: `extension`)
        return `extension`.name
    }
    
    /**
     Removes and unloads extensions with a matching name from the system.
     
     - Parameter extensionName: An extension name.
     */
    public func remove(_ extensionName: String) {
        timeline.remove(extensionName: extensionName)
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
 ExtensionType specifies where in the chain a given extension is to be executed.
 */
public enum ExtensionType: Int, CaseIterable {
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

public protocol Extension: AnyObject {
    var type: ExtensionType { get }
    var name: String { get }
    var analytics: Analytics { get }
    
    init(name: String, analytics: Analytics)
    func execute<T: RawEvent>(event: T?, settings: Settings?) -> T?
    func shutdown()
}

public protocol EventExtension: Extension {
    func identify(event: IdentifyEvent) -> IdentifyEvent?
    func track(event: TrackEvent) -> TrackEvent?
    func group(event: GroupEvent) -> GroupEvent?
    func alias(event: AliasEvent) -> AliasEvent?
    func screen(event: ScreenEvent) -> ScreenEvent?
}

public protocol DestinationExtension: EventExtension {
    var extensions: Extensions { get set }
}

public protocol UtilityExtension: EventExtension { }

// For internal platform-specific bits
internal protocol PlatformExtension: Extension {
    static var specificName: String { get set }
}


// MARK: - Extension Default Implementations

extension Extension {
    public func execute<T: RawEvent>(event: T?, settings: Settings?) -> T? {
        // do nothing.
        return event
    }

    public func shutdown() {
        // do nothing by default, user can override.
    }
}

extension EventExtension {
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

    // Default implementations that forward the event. This gives extension
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

extension DestinationExtension {
    func execute<T: RawEvent>(event: T?, settings: Settings?) -> T? {
        var result: T? = event
        if let r = result {
            result = self.process(incomingEvent: r)
        }
        return result
    }

    internal func process<E: RawEvent>(incomingEvent: E) -> E? {
        // This will process extensions (think destination middleware) that are tied
        // to this destination.
        
        // apply .before and .enrichment types first ...
        let beforeResult = extensions.timeline.applyExtensions(type: .before, event: incomingEvent)
        let enrichmentResult = extensions.timeline.applyExtensions(type: .enrichment, event: beforeResult)
        
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
        
        // apply .after extensions ...
        let afterResult = extensions.timeline.applyExtensions(type: .after, event: destinationResult)

        // DEBUG
        print("Destination (\(name)): \(afterResult?.prettyPrint() ?? "")")
        // DEBUG
        
        return afterResult
    }
}

