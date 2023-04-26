//
//  ObjCPlugin.swift
//  
//
//  Created by Brandon Sneed on 4/17/23.
//


#if !os(Linux)

import Foundation

@objc(SEGPlugin)
public protocol ObjCPlugin {}

public protocol ObjCPluginShim {
    func instance() -> EventPlugin
}

// NOTE: Destination plugins need something similar to the following to work/
/*

@objc(SEGMixpanelDestination)
public class ObjCSegmentMixpanel: NSObject, ObjCPlugin, ObjCPluginShim {
    public func instance() -> EventPlugin { return MixpanelDestination() }
}

*/

@objc(SEGEventPlugin)
public class ObjCEventPlugin: NSObject, EventPlugin, ObjCPlugin {
    public var type: PluginType = .enrichment
    public var analytics: Analytics? = nil
    
    @objc(executeEvent:)
    public func execute(event: ObjCRawEvent?) -> ObjCRawEvent? {
        #if DEBUG
        print("SEGEventPlugin's execute: method must be overridden!")
        #endif
        return event
    }
    
    public func execute<T>(event: T?) -> T? where T : RawEvent {
        let objcEvent = objcEventFromEvent(event)
        let result = execute(event: objcEvent)
        let newEvent = eventFromObjCEvent(result)
        return newEvent as? T
    }
}

@objc(SEGBlockPlugin)
public class ObjCBlockPlugin: ObjCEventPlugin {
    let block: (ObjCRawEvent?) -> ObjCRawEvent?
    
    @objc(executeEvent:)
    public override func execute(event: ObjCRawEvent?) -> ObjCRawEvent? {
        return block(event)
    }
    
    @objc(initWithBlock:)
    public init(block: @escaping (ObjCRawEvent?) -> ObjCRawEvent?) {
        self.block = block
    }
}

@objc
extension ObjCAnalytics {
    @objc(addPlugin:)
    public func add(plugin: ObjCPlugin?) {
        if let p = plugin as? ObjCPluginShim {
            analytics.add(plugin: p.instance())
        } else if let p = plugin as? ObjCEventPlugin {
            analytics.add(plugin: p)
        }
    }
    
    @objc(addPlugin:destinationKey:)
    public func add(plugin: ObjCPlugin?, destinationKey: String) {
        guard let d = analytics.find(key: destinationKey) else { return }
        
        if let p = plugin as? ObjCPluginShim {
            _ = d.add(plugin: p.instance())
        } else if let p = plugin as? ObjCEventPlugin {
            _ = d.add(plugin: p)
        }
    }
}

#endif

