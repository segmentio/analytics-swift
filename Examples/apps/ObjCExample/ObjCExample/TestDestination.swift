//
//  TestDestination.swift
//  ObjCExample
//
//  Created by Brandon Sneed on 4/14/23.
//

import Foundation
import Segment

@objc(SEGTestDestination)
public class ObjCTestDestination: NSObject, ObjCPlugin, ObjCPluginShim {
    public func instance() -> EventPlugin { return TestDestination() }
}

public class TestDestination: DestinationPlugin {
    public let key = "Booya"
    public let timeline = Timeline()
    public let type = PluginType.destination
    public var analytics: Analytics? = nil
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        print("some event came to visit us for xmas din din.")
        return event
    }
}
