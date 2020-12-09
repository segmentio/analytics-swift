//
//  Extension.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

public enum ExtensionType: Int, CaseIterable {
    case before
    case sourceEnrichment
    case destinationEnrichment
    case destination
    case after
}

public protocol Extension: AnyObject {
    var type: ExtensionType { get }
    var name: String { get }
    var analytics: Analytics? { get set }
    
    init(type: ExtensionType, name: String)
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
