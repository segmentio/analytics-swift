//
//  FlurryDestination.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/9/21.
//

// NOTE: You can see this plugin in use in the SwiftUIKitExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.  Please contact Flurry
// about providing full support and publishing if desired.
//
// Flurry SPM package can be found here: https://github.com/flurry/FlurrySwiftPackage

// MIT License
//
// Copyright (c) 2021 Segment
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/* If flurry ever gets their swift package working, we can re-enable this */

/*
import Foundation
import Segment
import FlurryAnalytics

/**
 An implmentation of the Flurry Analytics device mode destination as a plugin.
 */

class FlurryDestination: DestinationPlugin {
    let timeline: Timeline = Timeline()
    let type: PluginType = .destination
    let name: String
    var analytics: Analytics? = nil
    
    var started = false
    var screenTracksEvents = false
    
    required init(name: String) {
        self.name = name
    }
    
    func update(settings: Settings) {
        guard let jsonSettings = settings.integrationSettings(for: "Flurry") else { return }
        guard let flurryApiKey = jsonSettings["apiKey"] as? String else { return }
        
        let builder = FlurrySessionBuilder()
        
        if let sessionContinueSeconds = jsonSettings["sessionContinueSeconds"] as? Int {
            builder.withSessionContinueSeconds(sessionContinueSeconds)
        }
        
        if let screenTracksEvents = jsonSettings["screenTracksEvents"] as? Bool {
            self.screenTracksEvents = screenTracksEvents
        }
        
        Flurry.startSession(flurryApiKey, with: builder)
        started = true
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        guard started == true else { return event }
        
        Flurry.setUserID(event.userId)
        
        if let traits = event.traits?.dictionaryValue {
            if let gender = traits["gender"] as? String {
                Flurry.setGender(String(gender.prefix(1)))
            }
            
            if let value = traits["age"] as? String, let age = Int32(value) {
                Flurry.setAge(age)
            }
        }
        
        return event
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        guard started == true else { return event }
        
        let props = truncate(properties: event.properties?.dictionaryValue)
        Flurry.logEvent(event.event, withParameters: props)
        return event
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        guard started == true else { return event }
        
        if screenTracksEvents {
            let props = truncate(properties: event.properties?.dictionaryValue)
            Flurry.logEvent("Viewed \(event.name ?? "") Screen", withParameters: props)
        }
        return event
    }
}

// MARK: - Support methods

extension FlurryDestination {
    /**
     Flurry can only have a maximum of 10 properties, so we need to truncate any properties we were given.
     */
    func truncate(properties: [String: Any]?) -> [String: Any]? {
        guard let properties = properties else { return nil }
        var truncated = [String: Any]()
        for (key, value) in properties {
            truncated[key] = value
            if truncated.count == 10 {
                break
            }
        }
        return properties
    }
}

*/
