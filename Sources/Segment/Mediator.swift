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
        }
        
        return result
    }
}
