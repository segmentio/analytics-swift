//
//  Timeline.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran


internal class Timeline {
    internal let extensions: [ExtensionType: Mediator]
    
    internal init() {
        self.extensions = [
            .before: Mediator(),
            .enrichment: Mediator(),
            .destination: Mediator(),
            .after: Mediator(),
            .none: Mediator()
        ]
    }
    
    internal func process<E: RawEvent>(incomingEvent: E) -> E? {
        let beforeResult = applyExtensions(type: .before, event: incomingEvent)
        let enrichmentResult = applyExtensions(type: .enrichment, event: beforeResult)
        
        // once the event enters a destination, we don't want
        // to know about changes that happen there
        _ = applyExtensions(type: .destination, event: enrichmentResult)
        
        
        let afterResult = applyExtensions(type: .after, event: enrichmentResult)

        print("System: ")
        if afterResult == nil {
            print("event dropped.")
        } else {
            //
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                let json = try encoder.encode(afterResult)
                if let printed = String(data: json, encoding: .utf8) {
                    print(printed)
                }
            } catch {
                print(error)
            }
        }
        
        return afterResult
    }
    
    internal func applyExtensions<E: RawEvent>(type: ExtensionType, event: E?) -> E? {
        var result: E? = event
        let mediator = extensions[type]
        result = applyExtensions(mediator: mediator, event: event)
        return result
    }
    
    internal func applyExtensions<E: RawEvent>(mediator: Mediator?, event: E?) -> E? {
        var result: E? = event
        if let e = event {
            result = mediator?.execute(event: e)
        }
        return result
    }
}


// MARK: - Extension Support

extension Timeline {
    public func applyToExtensions(_ closure: (Extension) -> Void) {
        for type in ExtensionType.allCases {
            if let mediator = extensions[type] {
                mediator.extensions.forEach { (extension) in
                    closure(`extension`)
                }
            }
        }
    }
    
    internal func add(extension: Extension) {
        if let mediator = extensions[`extension`.type] {
            mediator.add(extension: `extension`)
        }
    }
    
    internal func remove(extensionName: String) {
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
