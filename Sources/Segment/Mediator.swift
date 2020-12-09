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
    
    func add(extension: Extension) {
        extensions.append(`extension`)
    }
    
    func remove(extensionName: String) {
        extensions.removeAll { (extension) -> Bool in
            return `extension`.name == extensionName
        }
    }
}
