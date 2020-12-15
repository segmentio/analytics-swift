//
//  Mediator.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

internal class Mediator {
    internal func add(extension: Extension) {
        if `extension`.type == .sequential {
            sequentialExtensions.append(`extension`)
        } else {
            extensions.append(`extension`)
        }
    }
    
    internal func remove(extensionName: String) {
        extensions.removeAll { (extension) -> Bool in
            return `extension`.name == extensionName
        }
        sequentialExtensions.removeAll { (extension) -> Bool in
            return `extension`.name == extensionName
        }
    }

    internal var extensions = [Extension]()
    internal var sequentialExtensions = [Extension]()
    internal func execute<T: RawEvent>(event: T) -> T? {
        var result: T? = event
        
        extensions.forEach { (extension) in
            if let destExt = `extension` as? DestinationExtension {
                if let r = result {
                    result = destExt.process(incomingEvent: r)
                    sequentialExtensions.forEach { (extension) in
                        `extension`.execute()
                    }
                }
            } else if let eventExt = `extension` as? EventExtension {
                switch result {
                case let r as IdentifyEvent:
                    result = eventExt.identify(event: r) as? T
                    sequentialExtensions.forEach { (extension) in
                        `extension`.execute()
                    }
                default:
                    print("something is screwed up")
                    break
                }
            }
        }
        
        // reapply any raw data that may have been lost.
        //result?.applyRawEventData(event: event)
        
        return result
    }
}
