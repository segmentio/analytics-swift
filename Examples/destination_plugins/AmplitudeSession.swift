//
//  AmplitudeSession.swift
//  DestinationsExample
//
//  Created by Cody Garvin on 2/16/21.
//

// NOTE: This Plugin replicates Amplitude's session tracking functionality. 
// It should be used to send session data to Amplitude via a cloud mode
// connection. Once implemented, the Amplitude SDK can be removed from 
// your application. 

// NOTE: You can see this plugin in use in the DestinationsExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.
//

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

class AmplitudeSession: EventPlugin, iOSLifecycle {
    var key = "Actions Amplitude"
    var type = PluginType.enrichment
    var analytics: Analytics?
    
    var active = false
    
    private var sessionTimer: Timer?
    private var sessionID: TimeInterval?
    private let fireTime = TimeInterval(300)
    
    func update(settings: Settings, type: UpdateType) {
        if settings.isDestinationEnabled(key: key) {
            active = true
        } else {
            active = false
        }
    }
    
    func execute<T: RawEvent>(event: T?) -> T? {
        if !active {
            return event
        }
        
        var result: T? = event
        switch result {
            case let r as IdentifyEvent:
                result = self.identify(event: r) as? T
            case let r as TrackEvent:
                result = self.track(event: r) as? T
            case let r as ScreenEvent:
                result = self.screen(event: r) as? T
            case let r as AliasEvent:
                result = self.alias(event: r) as? T
            case let r as GroupEvent:
                result = self.group(event: r) as? T
            default:
                break
        }
        return result
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        guard let returnEvent = insertSession(event: event) as? TrackEvent else {
            return nil
        }
        return returnEvent
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        guard let returnEvent = insertSession(event: event) as? IdentifyEvent else {
            return nil
        }
        return returnEvent
    }
    
    func alias(event: AliasEvent) -> AliasEvent? {
        guard let returnEvent = insertSession(event: event) as? AliasEvent else {
            return nil
        }
        return returnEvent
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        guard let returnEvent = insertSession(event: event) as? ScreenEvent else {
            return nil
        }
        return returnEvent
    }
    
    func group(event: GroupEvent) -> GroupEvent? {
        guard let returnEvent = insertSession(event: event) as? GroupEvent else {
            return nil
        }
        return returnEvent
    }
    
    func applicationWillEnterForeground(application: UIApplication?) {
        startTimer()
        analytics?.log(message: "Amplitude Session ID: \(sessionID ?? -1)")
    }

    func applicationWillResignActive(application: UIApplication?) {
        stopTimer()
    }
}


// MARK: - AmplitudeSession Helper Methods
extension AmplitudeSession {
    func insertSession(event: RawEvent) -> RawEvent {
        var returnEvent = event
        if var integrations = event.integrations?.dictionaryValue,
           let sessionID = sessionID {
            
            integrations[key] = ["session_id": (Int(sessionID) * 1000)]
            returnEvent.integrations = try? JSON(integrations as Any)
        }
        return returnEvent
    }
    
    @objc
    func handleTimerFire(_ timer: Timer) {
        stopTimer()
        startTimer()
    }
    
    func startTimer() {
        sessionTimer = Timer(timeInterval: fireTime, target: self,
                             selector: #selector(handleTimerFire(_:)),
                             userInfo: nil, repeats: true)
        sessionTimer?.tolerance = 0.3
        sessionID = Date().timeIntervalSince1970
        if let sessionTimer = sessionTimer {
            // Use the RunLoop current to avoid retaining self
            RunLoop.current.add(sessionTimer, forMode: .common)
        }
    }
    
    func stopTimer() {
        sessionTimer?.invalidate()
        sessionID = -1
    }
}
