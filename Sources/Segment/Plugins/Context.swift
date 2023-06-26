//
//  Context.swift
//  Segment
//
//  Created by Brandon Sneed on 2/23/21.
//

import Foundation

public protocol OpeningURLs {
    func openURL(_ url: URL, options: [String : Any])
}

extension OpeningURLs {
    func openURL(_ url: URL, options: [String : Any]) {}
}

public class Context: PlatformPlugin {
    public let type: PluginType = .before
    public weak var analytics: Analytics?
    
    internal var staticContext = staticContextData()
    internal static var device = VendorSystem.current
    internal let instanceId = UUID().uuidString
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        
        var context = staticContext
        
        insertDynamicPlatformContextData(context: &context)
        
        // add instanceId to the context
        context["instanceId"] = instanceId
        
        if let userInfo: UserInfo = analytics?.store.currentState(), let referrer = userInfo.referrer {
            context["referrer"] = ["url": referrer.absoluteString]
        }
        
        // if this event came in with context data already
        // let it take precedence over our values.
        if let eventContext = workingEvent.context?.dictionaryValue {
            context.merge(eventContext) { (_, new) in new }
        }
        
        do {
            workingEvent.context = try JSON(context)
        } catch {
            analytics?.reportInternalError(error)
        }
        
        return workingEvent
    }
    
    internal static func staticContextData() -> [String: Any] {
        var staticContext = [String: Any]()
        
        // library name
        staticContext["library"] = [
            "name": "analytics-swift",
            "version": __segment_version,
        ]
        
        // app info
        let info = Bundle.main.infoDictionary
        let localizedInfo = Bundle.main.localizedInfoDictionary
        var app = [String: Any]()
        if let info = info {
            app.merge(info) { (_, new) in new }
        }
        if let localizedInfo = localizedInfo {
            app.merge(localizedInfo) { (_, new) in new }
        }
        if app.count != 0 {
            staticContext["app"] = [
                "name": app["CFBundleDisplayName"] ?? "",
                "version": app["CFBundleShortVersionString"] ?? "",
                "build": app["CFBundleVersion"] ?? "",
                "namespace": Bundle.main.bundleIdentifier ?? ""
            ]
        }
        
        insertStaticPlatformContextData(context: &staticContext)
        
        return staticContext
    }
    
    internal static func insertStaticPlatformContextData(context: inout [String: Any]) {
        // device
        let device = Self.device
        
        // "token" handled in DeviceToken.swift
        context["device"] = [
            "manufacturer": device.manufacturer,
            "type": device.type,
            "model": device.model,
            "name": device.name,
            "id": device.identifierForVendor ?? ""
        ]
        // os
        context["os"] = [
            "name": device.systemName,
            "version": device.systemVersion
        ]
        // screen
        let screen = device.screenSize
        context["screen"] = [
            "width": screen.width,
            "height": screen.height
        ]
        // locale
        if Locale.preferredLanguages.count > 0 {
            context["locale"] = Locale.preferredLanguages[0]
        }
        // timezone
        context["timezone"] = TimeZone.current.identifier
    }

    internal func insertDynamicPlatformContextData(context: inout [String: Any]) {
        let device = Self.device
        
        // network
        let status = device.connection
        
        var cellular = false
        var wifi = false
        var bluetooth = false
        
        switch status {
        case .online(.cellular):
            cellular = true
        case .online(.wifi):
            wifi = true
        case .online(.bluetooth):
            bluetooth = true
        default:
            break
        }
        
        // network connectivity
        context["network"] = [
            "bluetooth": bluetooth, // not sure any swift platforms support this currently
            "cellular": cellular,
            "wifi": wifi
        ]
        
        // user-agent
        // BKS: This use to be in the static section, however it was discovered that on some platforms
        // there can be a delay in retrieval.  It has to be fetched on the main thread, so we've spun it off
        // async and cache it when it comes back.
        let userAgent = device.userAgent
        context["userAgent"] = userAgent

        // other stuff?? ...
    }

}
