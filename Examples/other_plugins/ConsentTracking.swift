//
//  ConsentTracking.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/9/21.
//

// NOTE: You can see this plugin in use in the SwiftUIKitExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.

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

import Foundation
import Segment
import UIKit

/**
 An example of implementing a consent management plugin.
 
 This plugin will display a dialog at startup requesting tracking consent. Until consent is given,
 any events that would flow through the system are queued so they can be replayed post-consent.
 
 If consent is declined, all events are dropped immediately after entering the event timeline.
 */
class ConsentTracking: Plugin {
    let type = PluginType.before
    weak var analytics: Analytics? = nil
    
    var queuedEvents = [RawEvent]()
    
    static var consentGiven = false
    static var consentAsked = false
    static var lock = NSLock()
    static var instances = [ConsentTracking]()
    
    init() {
        Self.instances.append(self)
        
        // In our example, we'll be adding this plugin to multiple instances of Analytics.
        // Because of this, we need a centralized point to determine whether we're allowed to
        // track or process events.
        if Self.lock.try() {
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: "Privacy Notice", message: "This app tracks you for X, Y and Z.  Do you consent?", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                    Self.consentGiven = true
                    Self.consentAsked = true
                    Self.lock.unlock()
                    
                    self.analytics?.track(name: "Consent to track given")
                    
                    // replay any queued events if they gave consent.
                    Self.replayEvents()
                }))
                
                alertController.addAction(UIAlertAction(title: "No", style: .destructive, handler: { _ in
                    Self.consentGiven = false
                    Self.consentAsked = true
                    Self.lock.unlock()
                    
                    // clear any queued events if it was denied.
                    Self.clearQueuedEvents()
                }))
                
                UIApplication.shared.windows.first?.rootViewController?.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    func execute<T: RawEvent>(event: T?) -> T? {
        // if we've been given consent, let the event pass through.
        if Self.consentGiven {
            return event
        }
        
        // queue the event in case they given consent later
        if let e = event, Self.consentAsked == false {
            queuedEvents.append(e)
        }
        
        // returning nil will stop processing the event in the timeline.
        return nil
    }
    
    static func clearQueuedEvents() {
        for instance in Self.instances {
            instance.queuedEvents.removeAll()
        }
    }
    
    static func replayEvents() {
        for instance in Self.instances {
            instance.replayEvents()
        }
        clearQueuedEvents()
    }
    
    func replayEvents() {
        // replay the queued events to the instance of Analytics we're working with.
        for event in queuedEvents {
            analytics?.process(event: event)
        }
    }
}
