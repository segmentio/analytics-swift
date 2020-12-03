//
//  Extension.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

enum ExtensionType: Int {
    case before
    case sourceEnrichment
    case destinationEnrichment
    case destination
    case after
}

protocol Extension {
    var type: ExtensionType { get }
    init(type: ExtensionType)
    
    func track(event: Event) -> Event
    func identify(event: Event) -> Event
    func page(event: Event) -> Event
    func group(event: Event) -> Event
    func alias(event: Event) -> Event
    func screen(event: Event) -> Event
}
