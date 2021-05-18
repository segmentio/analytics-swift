//
//  DeviceToken.swift
//  Segment
//
//  Created by Brandon Sneed on 3/24/21.
//

import Foundation

public class DeviceToken: PlatformPlugin {
    static var specificName = "Segment_DeviceToken"
    
    public let type: PluginType = .before
    public let name: String = specificName
    public var analytics: Analytics?
    
    public var token: String? = nil

    public required init(name: String) {
        // ignore `name` here, it's hard coded above.
    }
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        if var context = workingEvent.context?.dictionaryValue, let token = token {
            context[keyPath: "device.token"] = token
            do {
                workingEvent.context = try JSON(context)
            } catch {
                exceptionFailure("Unable to convert context to JSON: \(error)")
            }
        }
        return workingEvent
    }
}

extension Analytics {
    public func setDeviceToken(_ token: String) {
        if let tokenPlugin = self.find(pluginName: DeviceToken.specificName) as? DeviceToken {
            tokenPlugin.token = token
        } else {
            let tokenPlugin = DeviceToken(name: DeviceToken.specificName)
            tokenPlugin.token = token
            add(plugin: tokenPlugin)
        }
    }
}

extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}
