//
//  SegmentSwiftMixPanelPlugin.swift
//  SegmentExample
//
//  Created by Cody Garvin on 1/15/21.
//

import Segment
import Mixpanel

class SegmentMixPanel: DestinationPlugin {
    var type: PluginType
    var plugins: Plugins
    var name: String
    var analytics: Analytics
    private var mixPanel: Mixpanel? = nil
    
    required init(name: String, analytics: Analytics) {
        self.analytics = analytics
        self.name = name
        plugins = Plugins()
        type = .destination
        if let settings = analytics.settings(), let integrations = settings.integrations {
            // TODO: Look at possibility of default names after PoC
//            integrations["Mixpanel"]
            if let integrationsDict = integrations.dictionaryValue {
                print("Funky funky \(integrationsDict["Mixpanel"])")
            } else {
                print("we died")
            }
            mixPanel = Mixpanel.sharedInstance(withToken: "")//mixpanelToken)
        }
    }
    
    func reloadWithSettings(_ settings: Settings) {
        // TODO: Update the proper types
        if let integrationsDict = settings.integrations?.dictionaryValue {
            print("Funky funky \(integrationsDict["Mixpanel"])")
        } else {
            print("we died")
        }
//        mixPanel?.
    }
    
    func execute<T>(event: T?, settings: Settings?) -> T? where T : RawEvent {
        return event
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        return event
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        return event
    }
    
    func group(event: GroupEvent) -> GroupEvent? {
        return event
    }
    
    func alias(event: AliasEvent) -> AliasEvent? {
        return event
    }
}
