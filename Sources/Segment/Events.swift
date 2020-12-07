//
//  Events.swift
//  Segment
//
//  Created by Cody Garvin on 11/30/20.
//

import Foundation

extension Analytics {
    func track<P: Properties, I: Integrations>(name: String, properties: P? = nil, integrations: I? = nil) {
        // ...
    }
    
    // make a note in the docs on this that we removed the old "options" property
    // and they need to write a middleware/enrichment now.
    // the objc version should accomodate them if it's really needed.
    func identify<T: Traits>(userId: String, traits: T? = nil) {
        let event = IdentifyEvent(timeline: timeline, traits: traits)
    }
    
    func identify<T: Traits>(traits: T) {
        
    }
    

}
