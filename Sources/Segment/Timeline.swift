//
//  Timeline.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran

internal class Timeline {
    let extensions: [ExtensionType: Mediator]
    let store: Store
    
    init(store: Store) {
        self.store = store
        self.extensions = [
            .before: Mediator(),
            .sourceEnrichment: Mediator(),
            .destinationEnrichment: Mediator(),
            .destination: Mediator(),
            .after: Mediator()
        ]
    }
    
    func process<E: Codable>(event: E) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(event)
            if let printed = String(data: json, encoding: .utf8) {
                print(printed)
            }
        } catch {
            print(error)
        }
    }
    
}

// MARK: - Extension Support

extension Timeline {
    func applyToExtensions(_ closure: (Extension) -> Void) {
        for type in ExtensionType.allCases {
            if let mediator = extensions[type] {
                mediator.extensions.forEach { (extension) in
                    closure(`extension`)
                }
            }
        }
    }
    
    func add(extension: Extension) {
        if let mediator = extensions[`extension`.type] {
            mediator.add(extension: `extension`)
        }
    }
    
    func remove(extensionName: String) {
        // remove all extensions with this name in every category
        for type in ExtensionType.allCases {
            if let mediator = extensions[type] {
                let toRemove = mediator.extensions.filter { (extension) -> Bool in
                    return `extension`.name == extensionName
                }
                toRemove.forEach { (extension) in
                    mediator.remove(extensionName: extensionName)
                }
            }
        }
    }

}
