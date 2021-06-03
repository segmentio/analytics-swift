//
//  AmplitudeSession.swift
//  DestinationsExample
//
//  Created by Cody Garvin on 2/16/21.
//

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
    
    var type: PluginType
    var name: String
    var analytics: Analytics?
    
    private var sessionTimer: Timer?
    private var sessionID: TimeInterval?
    private let fireTime = TimeInterval(300)
    
    required init(name: String) {
        self.name = name
        self.type = .enrichment
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        let returnEvent = insertSession(event: event)
        return returnEvent
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        let returnEvent = insertSession(event: event)
        return returnEvent
    }
    
    func alias(event: AliasEvent) -> AliasEvent? {
        let returnEvent = insertSession(event: event)
        return returnEvent
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        let returnEvent = insertSession(event: event)
        return returnEvent
    }
    
    func group(event: GroupEvent) -> GroupEvent? {
        let returnEvent = insertSession(event: event)
        return returnEvent
    }
    
    func applicationWillBecomeActive() {
        startTimer()
    }
    
    func applicationWillResignActive() {
        stopTimer()
    }
}

// MARK: - AmplitudeSession Helper Methods
extension AmplitudeSession {
    
    func insertSession<T: RawEvent>(event: T) -> T {
        var returnEvent = event
        if var integrations = event.integrations?.dictionaryValue,
           let sessionID = sessionID {
            integrations["Amplitude"] = ["session_id": (Int(sessionID) * 1000)]
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
