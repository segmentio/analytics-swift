//
//  StartupQueue.swift
//  Segment
//
//  Created by Brandon Sneed on 6/4/21.
//

import Foundation
import Sovran

class StartupQueue: Plugin, Subscriber {
    static var specificName = "Segment_StartupQueue"
    static let maxSize = 1000

    @Atomic var running: Bool = false
    
    let type: PluginType = .before
    let name: String = specificName
    var analytics: Analytics? = nil {
        didSet {
            analytics?.store.subscribe(self, handler: runningUpdate)
        }
    }
    
    var queuedEvents = [RawEvent]()
    
    required init(name: String) {
        // ignore name; hardcoded above.
    }
    
    func execute<T: RawEvent>(event: T?) -> T? {
        if running == false, let e = event  {
            // timeline hasn't started, so queue it up.
            if queuedEvents.count >= Self.maxSize {
                // if we've exceeded the max queue size start dropping events
                queuedEvents.removeFirst()
            }
            queuedEvents.append(e)
            return nil
        }
        // the timeline has started, so let the event pass.
        return event
    }
}

extension StartupQueue {
    internal func runningUpdate(state: System) {
        running = state.running
        if running {
            replayEvents()
        }
    }
    
    internal func replayEvents() {
        // replay the queued events to the instance of Analytics we're working with.
        for event in queuedEvents {
            analytics?.process(event: event)
        }
        queuedEvents.removeAll()
    }
}
