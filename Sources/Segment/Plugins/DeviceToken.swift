//
//  DeviceToken.swift
//  Segment
//
//  Created by Brandon Sneed on 3/24/21.
//

import Foundation

public class DeviceToken: Plugin {
    static let SegmentTokenPluginName = "Segment_Token"
    
    public let type: PluginType = .before
    public let name: String = SegmentTokenPluginName
    public let analytics: Analytics
    
    public var token: String? = nil

    public required init(name: String, analytics: Analytics) {
        // ignore `name` here, it's hard coded above.
        self.analytics = analytics
    }
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        if var context = workingEvent.context?.dictionaryValue, let token = token {
            context[keyPath: "device.token"] = token
            workingEvent.context = try? JSON(context)
        }
        return workingEvent
    }
}

extension Analytics {
    public func setDeviceToken(_ token: String) {
        if let tokenPlugin = self.find(pluginName: DeviceToken.SegmentTokenPluginName) as? DeviceToken {
            tokenPlugin.token = token
        } else {
            let tokenPlugin = DeviceToken(name: DeviceToken.SegmentTokenPluginName, analytics: self)
            tokenPlugin.token = token
            add(plugin: tokenPlugin)
        }
    }
    
    public func setDeviceToken(_ token: Data) {
        setDeviceToken(token.hexString)
    }
}

extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}
