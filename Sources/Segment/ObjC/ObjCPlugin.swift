//
//  ObjCPlugin.swift
//  
//
//  Created by Brandon Sneed on 3/14/23.
//

#if !os(Linux)

import Foundation
import Sovran

internal class ObjCShimPlugin: Plugin, Subscriber {
    var type: PluginType = .enrichment
    var analytics: Analytics? = nil
    var executionBlock: (([String: Any]?) -> [String: Any]?)? = nil
    
    required init(middleware: @escaping ([String: Any]?) -> [String: Any]?) {
        executionBlock = middleware
    }
    
    func execute<T>(event: T?) -> T? where T : RawEvent {
        // is our event actually valid?
        guard let event = event else { return event }
        // do we actually have an execution block?
        guard let executionBlock = executionBlock else { return event }
        // can we conver this to a JSON dictionary?
        guard let dictEvent = try? JSON(with: event).dictionaryValue else { return event }
        // is it valid json?
        guard JSONSerialization.isValidJSONObject(dictEvent as Any) == true else { return event }
        // run the execution block, a nil result tells us to drop the event.
        guard let result = executionBlock(dictEvent) else { return nil }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
            let decoder = JSONDecoder()
            var newEvent: RawEvent? = nil
            switch event {
                case is IdentifyEvent:
                    newEvent = try? decoder.decode(IdentifyEvent.self, from: jsonData)
                case is TrackEvent:
                    newEvent = try? decoder.decode(TrackEvent.self, from: jsonData)
                case is ScreenEvent:
                    newEvent = try? decoder.decode(ScreenEvent.self, from: jsonData)
                case is AliasEvent:
                    newEvent = try? decoder.decode(AliasEvent.self, from: jsonData)
                case is GroupEvent:
                    newEvent = try? decoder.decode(GroupEvent.self, from: jsonData)
                default:
                    break
            }
            // return the decoded event ...
            return newEvent as? T
        } else {
            // we weren't able to serialize, so return the original event.
            return event
        }
    }
}

#endif
