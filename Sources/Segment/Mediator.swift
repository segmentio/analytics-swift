//
//  Mediator.swift
//  Segment-Tests
//
//  Created by Brandon Sneed on 12/3/20.
//

import Foundation

internal class Mediator {
    var extensions = [Extension]()
    init() {
        
    }
    
    func execute<T: RawEvent>(event: T) -> T? {
        var result: T? = event
        
        extensions.forEach { (extension) in
            if let eventExt = `extension` as? EventExtension {
                switch result {
                case let r as IdentifyEvent:
                    result = eventExt.identify(event: r) as? T
                default:
                    print("something is screwed up")
                    break
                }
            }
        }
        
        // reapply any raw data that may have been lost.
        result?.applyRawEventData(event: event)
        
        return result
    }
    
    func add(extension: Extension) {
        extensions.append(`extension`)
    }
    
    func remove(extensionName: String) {
        extensions.removeAll { (extension) -> Bool in
            return `extension`.name == extensionName
        }
    }
}
