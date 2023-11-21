//
//  NetBlockerFlushPolicy.swift
//  
//
//  Created by Brandon Sneed on 4/26/23.
//

import Foundation

// NOTE: You can see this task in use in the MacExample application.

// MIT License
//
// Copyright (c) 2023 Segment
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

public class NetBlockerFlushPolicy: FlushPolicy {
    public var type = PluginType.utility
    public weak var analytics: Segment.Analytics?
    
    static func networkBlockedHandler(error: Error, blockerPolicy: NetBlockerFlushPolicy) {
        switch error {
        case AnalyticsError.networkUnknown(let error):
            if let e = error as? URLError {
                if e.code == URLError.networkConnectionLost {
                    // Little Snitch might be running..
                    // lets disable analytics for now.
                    blockerPolicy.analytics?.enabled = false
                    print("The network appears to be blocked.  Disabling Analytics.")
                }
            }
        default:
            break
        }
    }
    
    public func configure(analytics: Segment.Analytics) {
        // if we've already been configured, exit.
        guard self.analytics == nil else { return }
        
        self.analytics = analytics
        // add our utility plugin portion of our policy ...
        // that way we can try to enable analytics when the app comes back to the foreground.
        self.analytics?.add(plugin: self)
    }
    
    public func shouldFlush() -> Bool {
        // if we're enabled, then flush.  if we don't know if we're enabled
        // it's probably because our analytics pointer became nil somehow, so
        // to prevent unexpected catastrophe, assume true.
        return self.analytics?.enabled ?? true
    }
    
    public func updateState(event: Segment.RawEvent) {
        // do nothing
    }
    
    public func reset() {
        // if we're told to reset.. lets try again.
        analytics?.enabled = true
    }
}

extension NetBlockerFlushPolicy: UtilityPlugin {
    // we can be a utility plugin as well to get lifecycle events to act on
    // see `type` defined in the main class above.
}

#if os(macOS)
extension NetBlockerFlushPolicy: macOSLifecycle {
    public func applicationDidBecomeActive() {
        // try to turn back on analytics and see if it's allowed ... if net is still
        // blocked, analytics will be disabled again.
        analytics?.enabled = true
        print("Turning analytics back on ...")
    }
}
#endif

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import UIKit
extension NetBlockerFlushPolicy: iOSLifecycle {
    public func applicationDidBecomeActive(application: UIApplication?) {
        // try to turn back on analytics and see if it's allowed ... if net is still
        // blocked, analytics will be disabled again.
        analytics?.enabled = true
        print("Turning analytics back on ...")
    }
}
#endif
