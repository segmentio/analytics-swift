//
//  Timeline.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran

class Timeline {
    internal let extensions: [ExtensionType: Mediator]
    internal let store = Store()
    
    init() {
        extensions = [
            .before: Mediator(),
            .sourceEnrichment: Mediator(),
            .destinationEnrichment: Mediator(),
            .destination: Mediator(),
            .after: Mediator()
        ]
        
        store.provide(state: UserInfo(anonymousId: UUID().uuidString, userId: nil, traits: nil))
    }
}
