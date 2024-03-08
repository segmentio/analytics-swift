//
//  QueueTimer.swift
//  Segment
//
//  Created by Brandon Sneed on 6/16/21.
//

import Foundation

internal class QueueTimer {
    enum State {
        case suspended
        case resumed
    }
    
    let interval: TimeInterval
    let timer: DispatchSourceTimer
    let queue: DispatchQueue
    let handler: () -> Void
    
    @Atomic var state: State = .suspended
    
    static var timers = [QueueTimer]()
    
    static func schedule(interval: TimeInterval, immediate: Bool = false, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        let timer = QueueTimer(interval: interval, queue: queue, handler: handler)
        Self.timers.append(timer)
    }

    init(interval: TimeInterval, immediate: Bool = false, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        self.interval = interval
        self.queue = queue
        self.handler = handler
        
        timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        if immediate {
            timer.schedule(deadline: .now(), repeating: self.interval)
        } else {
            timer.schedule(deadline: .now() + self.interval, repeating: self.interval)
        }
        timer.setEventHandler { [weak self] in
            self?.handler()
        }
        resume()
    }
    
    deinit {
        timer.setEventHandler {
            // do nothing ...
        }
        // if timer is suspended, we must resume if we're going to cancel.
        timer.cancel()
        resume()
    }
    
    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
    
    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }
}


extension TimeInterval {
    static func milliseconds(_ value: Int) -> TimeInterval {
        return TimeInterval(value / 1000)
    }
    
    static func seconds(_ value: Int) -> TimeInterval {
        return TimeInterval(value)
    }
    
    static func hours(_ value: Int) -> TimeInterval {
        return TimeInterval(60 * value)
    }
    
    static func days(_ value: Int) -> TimeInterval {
        return TimeInterval((60 * value) * 24)
    }
}
