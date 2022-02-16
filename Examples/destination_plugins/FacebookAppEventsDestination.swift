//
//  FacebookAppEventsDestination.swift
//  
//
//  Created by Brandon Sneed on 2/9/22.
//

import Foundation
import Segment
import FBSDKCoreKit

class FacebookAppEventsDestination: DestinationPlugin, iOSLifecycle {
    typealias FBSettings = FBSDKCoreKit.Settings
    
    let timeline = Timeline()
    let type = PluginType.destination
    let key = "Facebook App Events"
    var analytics: Analytics? = nil
    
    var dpOptions = ["LDU"]
    var dpCountry: Int32 = 0
    var dpState: Int32 = 0
    
    static let formatter = NumberFormatter()
    
    private var settings: FacebookAppEventsSettings? = nil
    
    init() {
        // creating formatters are expensive, so we make it static
        // and just set the style later.
        Self.formatter.numberStyle = .decimal
    }
    
    public func update(settings: Segment.Settings, type: UpdateType) {
        // we've already set up this singleton SDK, can't do it again, so skip.
        guard type == .initial else { return }
        
        guard let settings: FacebookAppEventsSettings = settings.integrationSettings(forPlugin: self) else { return }
        self.settings = settings
        
        FBSettings.shared.appID = settings.appId
        if let ldu = settings.limitedDataUse, ldu {
            FBSettings.shared.setDataProcessingOptions(dpOptions, country: dpCountry, state: dpState)
        } else {
            FBSettings.shared.setDataProcessingOptions(nil)
        }
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        // FB Event Names must be <= 40 characters
        let truncatedEventName = AppEvents.Name(String(event.event.prefix(40)))
        
        let revenue = extractRevenue(properties: event.properties, key: "revenue")
        let currency = extractCurrency(properties: event.properties, key: "currency")
        
        var params = extractParameters(properties: event.properties)
        
        if let revenue = revenue {
            params[AppEvents.ParameterName.currency] = currency
            
            AppEvents.shared.logEvent(truncatedEventName, valueToSum: revenue, parameters: params)
            AppEvents.shared.logPurchase(amount: revenue, currency: currency, parameters: params as? [String: Any])
        } else {
            AppEvents.shared.logEvent(truncatedEventName, parameters: params)
        }
        
        return event
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        // FB Event Names must be <= 40 characters
        // 'Viewed' and 'Screen' with spaces take up 14
        let truncatedEventName = String((event.name ?? "").prefix(26))
        let newEventName = "Viewed \(truncatedEventName) Screen"
        AppEvents.shared.logEvent(AppEvents.Name(newEventName))
        return event
    }
    
    func applicationDidBecomeActive(application: UIApplication?) {
        ApplicationDelegate.shared.initializeSDK()
    }
}

// MARK: Helper methods

extension FacebookAppEventsDestination {
    func extractParameters(properties: JSON?) -> [AppEvents.ParameterName: Any] {
        // Facebook only accepts properties/parameters that have an NSString key, and an NSString or NSNumber as a value.
        // ... so we need to strip out everything else.  Not doing so results in a refusal to send and an
        // error in the console from the FBSDK.
        var result = [AppEvents.ParameterName: Any]()
        guard let properties = properties?.dictionaryValue else { return result }
        
        for (key, value) in properties {
            switch value {
            case let v as NSString:
                result[AppEvents.ParameterName(key)] = v
            case let v as NSNumber:
                result[AppEvents.ParameterName(key)] = v
            default:
                break
            }
        }
        
        return result
    }
    
    func extractRevenue(properties: JSON?, key: String) -> Double? {
        guard let dict = properties?.dictionaryValue else { return nil }
        
        var revenue: Any? = nil
        for revenueKey in dict.keys {
            if key.caseInsensitiveCompare(revenueKey) == .orderedSame {
                revenue = dict[revenueKey]
            }
        }
        
        if revenue is String, let revenue = revenue as? String {
            // format the revenue
            let result = Self.formatter.number(from: revenue) as? Double
            return result
        } else if revenue is Double {
            return revenue as? Double
        }
        
        return nil
    }
    
    func extractCurrency(properties: JSON?, key: String) -> String {
        var result = "USD"
        guard let dict = properties?.dictionaryValue else { return result }
        let found = dict.keys.filter { dictKey in
            return (key.caseInsensitiveCompare(dictKey) == .orderedSame)
        }
        if let key = found.first, let value = dict[key] as? String {
            result = value
        }
        return result
    }
}

// MARK: Settings

private struct FacebookAppEventsSettings: Codable {
    let appId: String
    let limitedDataUse: Bool?
}

