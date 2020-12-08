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
