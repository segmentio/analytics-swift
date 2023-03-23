//
//  ObjCDestinationSupport.swift
//  
//
//  Created by Brandon Sneed on 3/23/23.
//

#if !os(Linux)

import Foundation
import Segment

@objc(SEGDestination)
public protocol ObjCDestination {}

public protocol ObjCDestinationShim {
    func instance() -> DestinationPlugin
}

// MARK: Mixpanel

#if canImport(SegmentMixpanel)
import SegmentMixpanel
@objc(SEGMixpanelDestination)
public class ObjCSegmentMixpanel: NSObject, ObjCDestination, ObjCDestinationShim {
    public func instance() -> DestinationPlugin { return MixpanelDestination() }
}
#endif



#endif // !os(Linux)
