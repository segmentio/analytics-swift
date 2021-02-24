//
//  Context.swift
//  Segment
//
//  Created by Brandon Sneed on 2/23/21.
//

import Foundation

public class Context: Plugin {
    public var type: PluginType
    public var name: String
    public var analytics: Analytics
    
    internal var staticContext = staticContextData()
    
    public required init(name: String, analytics: Analytics) {
        self.analytics = analytics
        self.name = name
        self.type = .before
    }
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        
        var context = staticContext
        
        // if this event came in with context data already
        // let it take precedence over our values.
        if let eventContext = workingEvent.context?.dictionaryValue {
            context.merge(eventContext) { (_, new) in new }
        }
        
        workingEvent.context = try? JSON(context)
        
        return workingEvent
    }
    
    internal static func staticContextData() -> [String: Any] {
        var staticContext = [String: Any]()
        
        // library name
        staticContext["library"] = [
            "name": "analytics-swift",
            "version": __segment_version
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
        
        // platform info, see <Platform>Utils.swift
        insertPlatformContextData(context: &staticContext)
        
        return staticContext
    }
    
}
