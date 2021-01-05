//
//  TestExtensions.swift
//  SegmentExample
//
//  Created by Brandon Sneed on 1/4/21.
//

import Foundation
import Segment

class GooberExtension: EventExtension {
    let type: ExtensionType
    let name: String
    
    required init(name: String) {
        self.name = name
        self.type = .enrichment
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        var newEvent = IdentifyEvent(existing: event)
        newEvent.userId = "goober"
        return newEvent
        //return nil
    }
}

class ZiggyExtension: EventExtension {
    let type: ExtensionType
    let name: String
    var completion: (() -> Void)?
    
    required init(name: String) {
        self.name = name
        self.type = .enrichment
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        var newEvent = IdentifyEvent(existing: event)
        newEvent.userId = "ziggy"
        return newEvent
        //return nil
    }
    
    func shutdown() {
        completion?()
    }
}

class MyDestination: DestinationExtension {
    var extensions: Extensions
    let type: ExtensionType
    let name: String
    
    required init(name: String) {
        self.name = name
        self.type = .destination
        self.extensions = Extensions()
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
}

class AfterExtension: Extension {
    var extensions: Extensions
    let type: ExtensionType
    let name: String
    
    required init(name: String) {
        self.name = name
        self.type = .after
        self.extensions = Extensions()
    }
    
    public func execute<T: RawEvent>(event: T?, settings: Settings?) -> T? {
        print(event.prettyPrint())
        return event
    }
}
