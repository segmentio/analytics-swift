//
//  NewRelicErrorReporting.swift
//  
//
//  Created by Brandon Sneed on 10/6/21.
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

protocol NewRelicConversion {
    var dictionaryValue: [String: Any]? { get }
}

class NewRelicErrorReporting: Plugin {
    let type = PluginType.enrichment
    var analytics: Analytics? = nil
    
    internal static let trackName = "__newrelic_error_report"
    internal static let errorKey = "__newrelic_error"
    
    internal let integrationKey = "New Relic"
    
    func execute<T: RawEvent>(event: T?) -> T? {
        // is it a track event?  if not, ignore it.
        guard let trackEvent = event as? TrackEvent else { return event }
        // is it the track event we're looking for?  If not, ignore it.
        guard trackEvent.event == Self.trackName else { return event }
        // we need to make a new integrations object to keep it from going anywhere
        // other than new relic
        guard let newIntegrations = try? JSON([integrationKey: true, "all": false])
        
        // it's what we're looking for, so lets make sure it *only* goes
        // to New Relic.
        trackEvent.integrations = newIntegrations
        return nil
    }
}

extension Analytics {
    func reportError(_ error: Error, attributes: [String: Any]?) {
        var newAttrs = [String: Any]()
        
        if let a = attributes {
            newAttrs = a
        }
        
        if let e = error as? NewRelicConversion, let value = e.dictionaryValue {
            newAttrs[NewRelicErrorReporting.errorKey] = value
        } else {
            newAttrs[NewRelicErrorReporting.errorKey] = error.localizedDescription
        }

        track(name: NewRelicErrorReporting.trackName, properties: newAttrs)
    }
    
    func reportError<A: Codable>(_ error: Error, attributes: A?) {
        if let a = attributes, let json = try? JSON(with: a) {
            reportError(error, attributes: json.dictionaryValue)
        } else {
            reportError(error, attributes: nil)
        }
    }
}
