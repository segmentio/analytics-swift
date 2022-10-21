//
//  DeviceToken.swift
//  Segment
//
//  Created by Brandon Sneed on 3/24/21.
//

import Foundation

public class DeviceToken: PlatformPlugin {
    public let type = PluginType.before
    public weak var analytics: Analytics?
    
    public var token: String? = nil

    public required init() { }
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        if var context = workingEvent.context?.dictionaryValue, let token = token {
            context[keyPath: "device.token"] = token
            do {
                workingEvent.context = try JSON(context)
            } catch {
                analytics?.reportInternalError(error)
            }
        }
        return workingEvent
    }
}

extension Analytics {
    public func setDeviceToken(_ token: String) {
        if let tokenPlugin = self.find(pluginType: DeviceToken.self) {
            tokenPlugin.token = token
        } else {
            let tokenPlugin = DeviceToken()
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
