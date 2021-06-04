//
//  EventQueue.swift
//  Segment
//
//  Created by Brandon Sneed on 6/4/21.
//

import Foundation

class EventQueue: Plugin {
    static var specificName = "Segment_EventQueue"
    static var queueSize = 100
    
    let type: PluginType = .before
    let name: String = specificName
    var analytics: Analytics? = nil
    
    var queuedEvents = [RawEvent]()
    
    required init(name: String) {
        // ignore name; hardcoded above.
    }
    
    func execute<T: RawEvent>(event: T?) -> T? {
        // if we've been given consent, let the event pass through.
        if destinationsStarted {
            replayEvents()
            return event
        } else if let e = event {
            // destinations haven't all started, so queue it up.
            queuedEvents.append(e)
            // don't let the queue get too large.
            if queuedEvents.count > Self.queueSize {
                queuedEvents.removeFirst()
            }
        }
        
        // returning nil will stop processing the event in the timeline.
        return nil
    }
}

extension EventQueue {
    var destinationsStarted: Bool {
        var result = false
        if let destinations = analytics?.timeline.plugins[.destination]?.plugins as? [DestinationPlugin] {
            result = true
            destinations.forEach { destination in
                if result == true && destination.started == false {
                    result = false
                }
            }
        }
        return result
    }
    
    func replayEvents() {
        // replay the queued events to the instance of Analytics we're working with.
        for event in queuedEvents {
            analytics?.process(event: event)
        }
        queuedEvents.removeAll()
    }
}
