//
//  ObjCDestinationSupport.swift
//  
//
//  Created by Brandon Sneed on 3/23/23.
//

#if !os(Linux)

import Foundation

@objc(SEGPlugin)
public protocol ObjCPlugin {}

public protocol ObjCPluginShim {
    func instance() -> EventPlugin
}

// NOTE: Destination plugins need something similar to the following to work
// in objective-c.

/*

@objc(SEGMixpanelDestination)
public class ObjCSegmentMixpanel: NSObject, ObjCPlugin, ObjCPluginShim {
    public func instance() -> EventPlugin { return MixpanelDestination() }
}

*/


#endif // !os(Linux)
