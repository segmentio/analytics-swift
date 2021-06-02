//
//  AmplitudeSession.swift
//  DestinationsExampleTests
//
//  Created by Cody Garvin on 2/16/21.
//

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
    
    func applicationWillBecomeActive() {
        startTimer()
        print(sessionID ?? "")
    }
    
    func applicationWillResignActive() {
        stopTimer()
    }
}

// MARK: - AmplitudeSession Helper Methods
extension AmplitudeSession {
    
    func insertSession(event: RawEvent) -> RawEvent {
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
        print("Timer Fired")
        print("Session: \(sessionID ?? -1)")
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
