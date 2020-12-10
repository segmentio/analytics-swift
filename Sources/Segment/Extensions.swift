//
//  Extensions.swift
//  Segment
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

public struct Extensions {
    internal let timeline = Timeline()
    
    public func apply(_ closure: (Extension) -> Void) {
        timeline.applyToExtensions(closure)
    }
    
    @discardableResult
    public func add(_ extension: Extension) -> String {
        timeline.add(extension: `extension`)
        return `extension`.name
    }
    
    public func remove(_ extensionName: String) {
        timeline.remove(extensionName: extensionName)
    }
}

public enum ExtensionType: Int, CaseIterable {
    case before
    case enrichment
    case destination
    case after
}

public protocol Extension: AnyObject {
    var type: ExtensionType { get }
    var name: String { get }
    var analytics: Analytics? { get set }
    
    init(name: String)
    func execute()
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

extension Extension {
    func execute() {
        // do nothing by default, user must override.
    }
}

extension EventExtension {
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
}

extension DestinationExtension {
    internal func process<E: RawEvent>(incomingEvent: E) -> E? {
        var event: E? = incomingEvent

        event = extensions.timeline.applyExtensions(type: .before, event: event)
        event = extensions.timeline.applyExtensions(type: .enrichment, event: event)
        
        switch event {
        case let r as IdentifyEvent:
            event = identify(event: r) as? E
        default:
            print("something is screwed up")
            break
        }
        
        event = extensions.timeline.applyExtensions(type: .after, event: event)

        print("Destination (\(name)):")
        if event == nil {
            print("event dropped.")
        } else {
            //
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                let json = try encoder.encode(event)
                if let printed = String(data: json, encoding: .utf8) {
                    print(printed)
                }
            } catch {
                print(error)
            }
        }
        
        return event
    }
}
