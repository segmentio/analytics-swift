//
//  QueuingCore.swift
//  
//
//  Created by Brandon Sneed on 6/3/21.
//

import Foundation

@objc
open class QueueingCore: NSObject {
    public var analytics: Analytics? = nil
    @Atomic public var started: Bool = false {
        didSet {
            if started == true {
                replayEvents()
            }
        }
    }
    
    internal var queuedEvents = [RawEvent]()
    
    open func execute<T: RawEvent>(event: T?) -> T? {
        if let e = event, started == false {
            queuedEvents.append(e)
            return nil
        }
        
        var result: T? = event
        switch result {
            case let r as IdentifyEvent:
                result = self.identify(event: r) as? T
            case let r as TrackEvent:
                result = self.track(event: r) as? T
            case let r as ScreenEvent:
                result = self.screen(event: r) as? T
            case let r as AliasEvent:
                result = self.alias(event: r) as? T
            case let r as GroupEvent:
                result = self.group(event: r) as? T
            default:
                break
        }
        return result
    }
    
    internal func replayEvents() {
        for event in queuedEvents {
            analytics?.process(event: event)
        }
        queuedEvents.removeAll()
    }
    
    open func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
    
    open func track(event: TrackEvent) -> TrackEvent? {
        return event
    }
    
    open func screen(event: ScreenEvent) -> ScreenEvent? {
        return event
    }
    
    open func group(event: GroupEvent) -> GroupEvent? {
        return event
    }
    
    open func alias(event: AliasEvent) -> AliasEvent? {
        return event
    }
}
