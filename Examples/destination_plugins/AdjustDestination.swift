//
//  AdjustDestination.swift
//  DestinationsExample
//
//  Created by Brandon Sneed on 5/27/21.
//
// NOTE: You can see this plugin in use in the DestinationsExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.
//
// Adjust SPM package can be found here: https://github.com/adjust/ios_sdk
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
import Adjust

@objc
class AdjustDestination: NSObject, DestinationPlugin, RemoteNotifications {
    let timeline = Timeline()
    let type = PluginType.destination
    let key = "Adjust"
    weak var analytics: Analytics? = nil
    
    private var settings: AdjustSettings? = nil
    
    public func update(settings: Settings, type: UpdateType) {
        // we've already set up this singleton SDK, can't do it again, so skip.
        guard type == .initial else { return }
        
        guard let settings: AdjustSettings = settings.integrationSettings(forPlugin: self) else { return }
        self.settings = settings
        
        var environment = ADJEnvironmentSandbox
        if let _ = settings.setEnvironmentProduction {
            environment = ADJEnvironmentProduction
        }
        
        let adjustConfig = ADJConfig(appToken: settings.appToken, environment: environment)
        
        if let bufferingEnabled = settings.setEventBufferingEnabled {
            adjustConfig?.eventBufferingEnabled = bufferingEnabled
        }
        
        if let _ = settings.trackAttributionData {
            adjustConfig?.delegate = self
        }
        
        if let useDelay = settings.setDelay, useDelay == true, let delayTime = settings.delayTime {
            adjustConfig?.delayStart = delayTime
        }
        
        Adjust.appDidLaunch(adjustConfig)
    }
    
    public func identify(event: IdentifyEvent) -> IdentifyEvent? {
        if let userId = event.userId, userId.count > 0 {
            Adjust.addSessionPartnerParameter("user_id", value: userId)
        }
        
        if let anonId = event.anonymousId, anonId.count > 0 {
            Adjust.addSessionPartnerParameter("anonymous_id", value: anonId)
        }
        
        return event
    }
    
    public func track(event: TrackEvent) -> TrackEvent? {
        if let anonId = event.anonymousId, anonId.count > 0 {
            Adjust.addSessionPartnerParameter("anonymous_id", value: anonId)
        }
        
        if let token = mappedCustomEventToken(eventName: event.event) {
            let adjEvent = ADJEvent(eventToken: token)
            
            let properties = event.properties?.dictionaryValue
            if let properties = properties {
                for (key, value) in properties {
                    adjEvent?.addCallbackParameter(key, value: "\(value)")
                }
            }
            
            let revenue: Double? = extract(key: "revenue", from: properties)
            let currency: String? = extract(key: "currency", from: properties, withDefault: "USD")
            let orderId: String? = extract(key: "orderId", from: properties)

            if let revenue = revenue, let currency = currency {
                adjEvent?.setRevenue(revenue, currency: currency)
            }
            
            if let orderId = orderId {
                adjEvent?.setTransactionId(orderId)
            }
            
        }

        return event
    }
    
    public func reset() {
        Adjust.resetSessionPartnerParameters()
    }
    
    public func registeredForRemoteNotifications(deviceToken: Data) {
        Adjust.setDeviceToken(deviceToken)
    }
}

// MARK: - Adjust Delegate conformance
extension AdjustDestination: AdjustDelegate {
    public func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        let campaign: [String: Any] = [
            "source": attribution?.network ?? NSNull(),
            "name": attribution?.campaign ?? NSNull(),
            "content": attribution?.clickLabel ?? NSNull(),
            "adCreative": attribution?.creative ?? NSNull(),
            "adGroup": attribution?.adgroup ?? NSNull()
        ]
        
        let properties: [String: Any] = [
            "provider": "Adjust",
            "trackerToken": attribution?.trackerToken ?? NSNull(),
            "trackerName": attribution?.trackerName ?? NSNull(),
            "campaign": campaign
        ]
        
        analytics?.track(name: "Install Attributed", properties: properties)
    }
}

// MARK: - Support methods
extension AdjustDestination {
    internal func mappedCustomEventToken(eventName: String) -> String? {
        var result: String? = nil
        if let tokens = settings?.customEvents?.dictionaryValue {
            result = tokens[eventName] as? String
        }
        return result
    }
    
    internal func extract<T>(key: String, from properties: [String: Any]?, withDefault value: T? = nil) -> T? {
        var result: T? = value
        guard let properties = properties else { return result }
        for (propKey, propValue) in properties {
            // not sure if this comparison is actually necessary,
            // but existed in the old destination so ...
            if key.lowercased() == propKey.lowercased() {
                if let value = propValue as? T {
                    result = value
                    break
                }
            }
        }
        return result
    }
}

private struct AdjustSettings: Codable {
    let appToken: String
    let setEnvironmentProduction: Bool?
    let setEventBufferingEnabled: Bool?
    let trackAttributionData: Bool?
    let setDelay: Bool?
    let customEvents: JSON?
    let delayTime: Double?
}
