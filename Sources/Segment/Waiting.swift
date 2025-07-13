//
//  Waiting.swift
//  Segment
//
//  Created by Brandon Sneed on 7/12/25.
//
import Foundation

public protocol WaitingPlugin: Plugin {}

extension Analytics {
    /// Pauses event processing, causing events to be queued.  When processing resumes
    /// any queued events will be replayed to the system with their original timestamps.
    /// The system will forcibly resume after 30 seconds, but you should
    /// call `resumeEventProcessing(plugin:)` when you've completed your task.
    public func pauseEventProcessing(plugin: WaitingPlugin) {
        store.dispatch(action: System.AddWaitingPlugin(plugin: plugin))
        pauseEventProcessing()
    }
    
    /// Resume event processing.  Any queued events will be replayed into the system
    /// using their original timestamps.
    public func resumeEventProcessing(plugin: WaitingPlugin) {
        store.dispatch(action: System.RemoveWaitingPlugin(plugin: plugin))
        resumeEventProcessing()
    }
}

extension Analytics {
    internal func running() -> Bool {
        if let system: System = store.currentState() {
            return system.running
        }
        // we have no state, so assume no.
        return false
    }
    
    internal func pauseEventProcessing() {
        let running = running()
        // if we're already paused, ignore and leave.
        if !running {
            return
        }
        // pause processing
        store.dispatch(action: System.ToggleRunningAction(running: false))
        // if we WERE running, someone stopped us, set a timer for
        // 30 seconds so they can't keep the system stopped forever.
        startProcessingAfterTimeout()
    }
    
    internal func resumeEventProcessing() {
        let running = running()
        // if we're already running, ignore and leave.
        if running {
            return
        }
        store.dispatch(action: System.ToggleRunningAction(running: true))
    }
    
    internal func startProcessingAfterTimeout() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.processingTimer?.cancel()
            self.processingTimer = DispatchWorkItem { [weak self] in
                self?.store.dispatch(action: System.ForceRunningAction())
                self?.processingTimer = nil // clean up after ourselves
            }
            if let processingTimer = self.processingTimer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: processingTimer)
            }
        }
    }
}
