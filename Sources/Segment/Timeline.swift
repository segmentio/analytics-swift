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
    var analytics: Analytics? = nil
    
    init() {
        self.extensions = [
            .before: Mediator(),
            .sourceEnrichment: Mediator(),
            .destinationEnrichment: Mediator(),
            .destination: Mediator(),
            .after: Mediator()
        ]
    }
    
    func process<E: RawEvent>(incomingEvent: E) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        var event: E? = incomingEvent

        event = applyExtensions(type: .before, event: event)
        event = applyExtensions(type: .sourceEnrichment, event: event)
        
        // TODO: these two are executing incorrectly
        event = applyExtensions(type: .destinationEnrichment, event: event)
        event = applyExtensions(type: .destination, event: event)
        
        event = applyExtensions(type: .after, event: event)

        if event == nil {
            print("event dropped.")
        } else {
            //
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
    
    func applyExtensions<E: RawEvent>(type: ExtensionType, event: E?) -> E? {
        var result: E? = event
        let mediator = extensions[type]
        if let e = event {
            result = mediator?.execute(event: e)
        }
        return result
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
