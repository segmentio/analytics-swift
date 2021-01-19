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
    private let mixPanel: Mixpanel?
    
    required init(name: String, analytics: Analytics) {
        self.analytics = analytics
        self.name = name
        plugins = Plugins()
        type = .destination
        if let settings = analytics.settings(), let integrations = settings.integrations {
//            integrations["Mixpanel"]
            mixPanel = Mixpanel.sharedInstance(withToken: "")//mixpanelToken)
        } else {
            fatalError("Could not instantiate Mix Panel")
        }
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
