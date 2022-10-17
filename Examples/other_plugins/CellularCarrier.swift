//
//  CellularCarrier.swift
//  
//
//  Created by Brandon Sneed on 4/12/22.
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

#if os(iOS) && !targetEnvironment(macCatalyst)

import Foundation
import Segment
import CoreTelephony

/**
 An example plugin to retrieve cellular information.
 
 This plugin will add all carrier information to the event's context.network object if cellular
 is currently in use.  Example contents:
 
 {
    "home": "T-Mobile",
    "roaming": "AT&T",
    "secondary": "Verizon",
 }
 
 */
class CellularCarrier: Plugin {
    var type: PluginType = .enrichment
    
    weak var analytics: Analytics?
    
    func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        
        if let isCellular: Bool = workingEvent.context?[keyPath: "network.cellular"],
            isCellular,
           let carriers = self.carriers
        {
            workingEvent.context?[keyPath: "network.carriers"] = carriers
        }

        return workingEvent
    }
    
    // done as a compute-once stored property; your use case may be different.
    var carriers: [String: String]? = {
        let info = CTTelephonyNetworkInfo()
        if let providers = info.serviceSubscriberCellularProviders {
            var results = [String: String]()
            for (key, value) in providers {
                if let carrier = value.carrierName, !carrier.isEmpty {
                    results[key] = value.carrierName
                }
            }
            if !results.isEmpty {
                return results
            }
        }
        return nil
    }()
}


/**
 An example plugin to retrieve cellular information.
 
 This plugin will add primary ("home") carrier information to the event's context.network object if cellular
 is currently in use.  This mimics the operation of the analytics-ios SDK.
 */
class PrimaryCellularCarrier: Plugin {
    var type: PluginType = .enrichment
    
    var analytics: Analytics?
    
    func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        
        if let isCellular: Bool = workingEvent.context?[keyPath: "network"],
            isCellular,
           let carrier = self.carrier
        {
            workingEvent.context?[keyPath: "network.carriers"] = carrier
        }

        return workingEvent
    }
    
    // done as a compute-once stored property; your use case may be different.
    var carrier: String? = {
        let info = CTTelephonyNetworkInfo()
        if let providers = info.serviceSubscriberCellularProviders {
            let primary = providers["home"]
            if let carrier = primary?.carrierName, !carrier.isEmpty {
                return carrier
            }
        }
        return nil
    }()
}

#endif
