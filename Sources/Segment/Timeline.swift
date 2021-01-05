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
            .utility: Mediator()
        ]
    }
    
    internal func process<E: RawEvent>(incomingEvent: E) -> E? {
        // apply .before and .enrichment types first ...
        let beforeResult = applyExtensions(type: .before, event: incomingEvent)
        // .enrichment here is akin to source middleware in the old analytics-ios.
        let enrichmentResult = applyExtensions(type: .enrichment, event: beforeResult)
        
        // once the event enters a destination, we don't want
        // to know about changes that happen there. those changes
        // are to only be received by the destination.
        _ = applyExtensions(type: .destination, event: enrichmentResult)
        
        // apply .after extensions ...
        let afterResult = applyExtensions(type: .after, event: enrichmentResult)

        // DEBUG
        print("System Results: \(afterResult?.prettyPrint() ?? "")")
        // DEBUG
        
        return afterResult
    }
    
    // helper method used by DestinationExtensions and Timeline
    internal func applyExtensions<E: RawEvent>(type: ExtensionType, event: E?) -> E? {
        var result: E? = event
        if let mediator = extensions[type], let e = event {
            result = mediator.execute(event: e)
        }
        return result
    }
}


// MARK: - Extension Support

/**
 This suite of functions supplies core functionality back up to the public
 `Extension` type.
 */
extension Timeline {
    internal func applyToExtensions(_ closure: (Extension) -> Void) {
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
                    `extension`.shutdown()
                    mediator.remove(extensionName: extensionName)
                }
            }
        }
    }

}
