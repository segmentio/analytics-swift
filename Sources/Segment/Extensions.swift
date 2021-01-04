//
//  Extensions.swift
//  Segment
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

public struct Extensions {
    internal let timeline = Timeline()
    internal var analytics: Analytics? = nil
    
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
        `extension`.analytics = analytics
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
    case none
}

public protocol Extension: AnyObject {
    var type: ExtensionType { get }
    var name: String { get }
    var analytics: Analytics? { get set }
    
    init(name: String)
    func execute(event: RawEvent?, settings: Settings?)
}

public protocol EventExtension: Extension {
    func identify(event: IdentifyEvent) -> IdentifyEvent?
    
    /*
    func track(event: Event) -> Event
    func identify(event: Event) -> Event
    func page(event: Event) -> Event
    func group(event: Event) -> Event
    func alias(event: Event) -> Event
    func screen(event: Event) -> Event*/
}

public protocol DestinationExtension: EventExtension {
    var extensions: Extensions { get set }
}


// MARK: - Extension Default Implementations

/*extension Extension {
    func execute(event: RawEvent? = nil, settings: Settings? = nil) {
        // do nothing by default, user must override.
    }
}*/

/*
 /*
 if let destExt = `extension` as? DestinationExtension {
     if let r = result {
         result = destExt.process(incomingEvent: r)
     }
 } else if let eventExt = `extension` as? EventExtension {
     switch result {
     case let r as IdentifyEvent:
         result = eventExt.identify(event: r) as? T
     default:
         print("something is screwed up")
         break
     }
 }*/
 */

extension EventExtension {
    /*func execute(event: RawEvent? = nil, settings: Settings? = nil) {
        // do nothing by default, user must override.
    }*/

    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
}

extension DestinationExtension {
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
        default:
            print("something is screwed up")
            break
        }
        
        // apply .after extensions ...
        let afterResult = extensions.timeline.applyExtensions(type: .after, event: destinationResult)

        // DEBUG
        print("Destination (\(name)):")
        if afterResult == nil {
            print("event dropped.")
        } else {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                let json = try encoder.encode(afterResult)
                if let printed = String(data: json, encoding: .utf8) {
                    print(printed)
                }
            } catch {
                print(error)
            }
        }
        // DEBUG
        
        return afterResult
    }
}
