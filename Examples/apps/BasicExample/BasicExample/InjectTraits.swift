//
//  InjectTraits.swift
//  BasicExample
//
//  Created by Alan Charles on 12/7/22.
//

import Foundation
import Segment

class InjectTraits: Plugin {
    let type = PluginType.enrichment
    weak var analytics: Analytics? = nil
    
    func execute<T: RawEvent>(event: T?) -> T? {
        if event?.type == "identify" {
            return event
        }
        
        var workingEvent = event
        
        if var context = event?.context?.dictionaryValue {
            context[keyPath: "traits"] = analytics?.traits()
            
            workingEvent?.context = try? JSON(context)
        }
        
        return workingEvent
    }
}
