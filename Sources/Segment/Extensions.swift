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
    
    public func apply(_ closure: (Extension) -> Void) {
        timeline.applyToExtensions(closure)
    }
    
    @discardableResult
    public func add(_ extension: Extension) -> String {
        `extension`.analytics = analytics
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

extension Extension {
    func execute(event: RawEvent? = nil, settings: Settings? = nil) {
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
        let beforeResult = extensions.timeline.applyExtensions(type: .before, event: incomingEvent)
        let enrichmentResult = extensions.timeline.applyExtensions(type: .enrichment, event: beforeResult)
        
        var destinationResult: E? = nil
        switch enrichmentResult {
        case let e as IdentifyEvent:
            destinationResult = identify(event: e) as? E
        default:
            print("something is screwed up")
            break
        }
        
        let afterResult = extensions.timeline.applyExtensions(type: .after, event: destinationResult)

        print("Destination (\(name)):")
        if afterResult == nil {
            print("event dropped.")
        } else {
            //
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
        
        return afterResult
    }
}
