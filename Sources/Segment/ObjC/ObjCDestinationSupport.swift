//
//  ObjCDestinationSupport.swift
//  
//
//  Created by Brandon Sneed on 3/23/23.
//

#if !os(Linux)

import Foundation

@objc(SEGDestination)
public protocol ObjCDestination {}

public protocol ObjCDestinationShim {
    func instance() -> DestinationPlugin
}

// NOTE: Destination plugins need something similar to the following to work
// in objective-c.

/*

@objc(SEGMixpanelDestination)
public class ObjCSegmentMixpanel: NSObject, ObjCDestination, ObjCDestinationShim {
    public func instance() -> DestinationPlugin { return MixpanelDestination() }
}

*/


#endif // !os(Linux)
