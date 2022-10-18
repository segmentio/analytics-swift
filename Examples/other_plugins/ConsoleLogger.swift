//
//  ConsoleLogger.swift
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

/**
 A generic console logging plugin.  The type `.after` signifies that this plugin will
 run at the end of the event timeline, at which point it will print event data to the Xcode console window.
 */
class ConsoleLogger: Plugin {
    let type = PluginType.after
    let name: String
    weak var analytics: Analytics? = nil
    
    var identifier: String? = nil
    
    required init(name: String) {
        self.name = name
    }
    
    // we want to log every event, so lets override `execute`.
    func execute<T: RawEvent>(event: T?) -> T? {
        if let json = event?.prettyPrint() {
            analytics?.log(message: "event received on instance: \(name)")
            analytics?.log(message: "\(json)\n")
        }
        return event
    }
    
    // we also want to know when settings are retrieved or changed.
    func update(settings: Settings) {
        let json = settings.prettyPrint()
        analytics?.log(message: "settings updated on instance: \(name)\nPayload: \(json)")
    }
    
}
