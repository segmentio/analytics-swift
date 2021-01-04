//
//  Mediator.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

internal class Mediator {
    internal func add(extension: Extension) {
        extensions.append(`extension`)
    }
    
    internal func remove(extensionName: String) {
        extensions.removeAll { (extension) -> Bool in
            return `extension`.name == extensionName
        }
    }

    internal var extensions = [Extension]()
    internal func execute<T: RawEvent>(event: T) -> T? {
        var result: T? = event
        
        extensions.forEach { (extension) in
            if let r = result {
                result = execute(event: r)
            }
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
        }
        
        return result
    }
}
