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
    
    @Atomic var started: Bool = false
    
    let type: PluginType = .before
    let name: String = specificName
    var analytics: Analytics? = nil {
        didSet {
            analytics?.store.subscribe(self, handler: systemUpdate)
        }
    }
    
    var queuedEvents = [RawEvent]()
    
    required init(name: String) {
        // ignore name; hardcoded above.
    }
    
    func execute<T: RawEvent>(event: T?) -> T? {
        if let e = event, started == false  {
            // timeline hasn't started, so queue it up.
            queuedEvents.append(e)
            return nil
        }
        // the timeline has started, so let the event pass.
        return event
    }
}

extension StartupQueue {
    internal func systemUpdate(state: System) {
        started = state.started
        if started {
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
