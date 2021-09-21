//
//  FirebaseDestination.swift
//  DestinationsExample
//
//  Created by Cody Garvin on 6/3/21.
//

// NOTE: You can see this plugin in use in the DestinationsExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.
//
// Firebase SPM package can be found here: https://github.com/firebase/firebase-ios-sdk

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
import FirebaseCore
import FirebaseAnalytics

/**
 An implmentation of the Firebase Analytics device mode destination as a plugin.
 */

class FirebaseDestination: DestinationPlugin {
    let timeline = Timeline()
    let type = PluginType.destination
    let key = "Firebase"
    var analytics: Segment.Analytics? = nil
    
    func update(settings: Settings, type: UpdateType) {
        // we've already set up this singleton SDK, can't do it again, so skip.
        guard type == .initial else { return }
        
        guard let firebaseSettings: FirebaseSettings = settings.integrationSettings(forPlugin: self) else { return }
        if let deepLinkURLScheme = firebaseSettings.deepLinkURLScheme {
            FirebaseOptions.defaultOptions()?.deepLinkURLScheme = deepLinkURLScheme
            analytics?.log(message: "Added deepLinkURLScheme: \(deepLinkURLScheme)")
        }
        
        // First check if firebase has been set up from a previous settings call
        if (FirebaseApp.app() != nil) {
            analytics?.log(message: "Firebase already configured, skipping")
        } else {
            FirebaseApp.configure()
        }
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        
        if let userId = event.userId {
            FirebaseAnalytics.Analytics.setUserID(userId)
            analytics?.log(message: "Firebase setUserId(\(userId))")
        }
        
        // Check the user properties for type
        if let traits = event.traits,
           let mapDictionary = traits.dictionaryValue {
            // Send off to identify
            mapToStrings(mapDictionary) { key, data in
                FirebaseAnalytics.Analytics.setUserProperty(data, forName: key)
                analytics?.log(message: "Firebase setUserPropertyString \(data) for key \(key)")
            }
        }
        
        return event
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        
        let name = formatFirebaseEventNames(event.event)
        var parameters: [String: Any]? = nil
        if let properties = event.properties?.dictionaryValue {
            parameters = returnMappedFirebaseParameters(properties)
        }
        
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
        analytics?.log(message: "Firebase logEventWithName \(name) parameters \(String(describing: parameters))")
        return event
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        
        if let eventName = event.name {
            FirebaseAnalytics.Analytics.logEvent(FirebaseAnalytics.AnalyticsEventScreenView,
                                                 parameters: [FirebaseAnalytics.AnalyticsParameterScreenName: eventName])
            analytics?.log(message: "Firebase setScreenName \(eventName)")
        }


        return event
    }
}

// MARK: - Support methods

extension FirebaseDestination {
    
    // Maps Segment spec to Firebase constant
    func formatFirebaseEventNames(_ eventName: String) -> String {
        
        if let mappedEvent = FirebaseDestination.mappedValues[eventName] {
            return mappedEvent
        } else {
            return (try? formatFirebaseName(eventName)) ?? eventName
        }
    }
    
    func formatFirebaseName(_ eventName: String) throws -> String {
        let trimmed = eventName.trimmingCharacters(in: .whitespaces)
        do {
            let regex = try NSRegularExpression(pattern: "([^a-zA-Z0-9_])", options: .caseInsensitive)
            let formattedString = regex.stringByReplacingMatches(in: trimmed, options: .reportProgress, range: NSMakeRange(0, trimmed.count), withTemplate: "_")
            
            // Resize the string to maximum 40 characters if needed
            let range = NSRange(location: 0, length: min(formattedString.count, 40))
            return NSString(string: formattedString).substring(with: range)
        } catch {
            analytics?.log(message: "Could not parse event name for Firebase.")
            throw(error)
        }
    }
    
    func returnMappedFirebaseParameters(_ properties: [String: Any]) -> [String: Any] {
        
        
        var mappedValues = properties
        
        for (key, firebaseKey) in FirebaseDestination.mappedKeys {
            if var data = properties[key] {
                
                mappedValues.removeValue(forKey: key)
                
                if let castData = data as? [String: Any] {
                    data = returnMappedFirebaseParameters(castData)
                } else if let castArray = data as? [Any] {
                    var updatedArray = [Any]()
                    for item in castArray {
                        if let castDictionary = item as? [String: Any] {
                            updatedArray.append(returnMappedFirebaseParameters(castDictionary))
                        } else {
                            updatedArray.append(item)
                        }
                    }
                    data = updatedArray
                }
                
                // Check key name for proper format
                if let updatedFirebaseKey = try? formatFirebaseName(firebaseKey) {
                    mappedValues[updatedFirebaseKey] = data
                }
            }
        }
        
        return mappedValues
    }
    
    // Makes sure all traits are string based for Firebase API
    func mapToStrings(_ mapDictionary: [String: Any], finalize: (String, String) -> Void) {
        
        for (key, data) in mapDictionary {
            var dataString = data as? String ?? "\(data)"
            let keyString = key.replacingOccurrences(of: " ", with: "_")
            dataString = dataString.trimmingCharacters(in: .whitespacesAndNewlines)
            finalize(keyString, dataString)
        }
    }
}


private struct FirebaseSettings: Codable {
    let deepLinkURLScheme: String?
}

private extension FirebaseDestination {
    
    static let mappedValues = ["Product Clicked": FirebaseAnalytics.AnalyticsEventSelectContent,
                               "Product Viewed": FirebaseAnalytics.AnalyticsEventViewItem,
                               "Product Added": FirebaseAnalytics.AnalyticsEventAddToCart,
                               "Product Removed": FirebaseAnalytics.AnalyticsEventRemoveFromCart,
                               "Checkout Started": FirebaseAnalytics.AnalyticsEventBeginCheckout,
                               "Promotion Viewed": FirebaseAnalytics.AnalyticsEventPresentOffer,
                               "Payment Info Entered": FirebaseAnalytics.AnalyticsEventAddPaymentInfo,
                               "Order Completed": FirebaseAnalytics.AnalyticsEventPurchase,
                               "Order Refunded": FirebaseAnalytics.AnalyticsEventRefund,
                               "Product List Viewed": FirebaseAnalytics.AnalyticsEventViewItemList,
                               "Product Added to Wishlist": FirebaseAnalytics.AnalyticsEventAddToWishlist,
                               "Product Shared": FirebaseAnalytics.AnalyticsEventShare,
                               "Cart Shared": FirebaseAnalytics.AnalyticsEventShare,
                               "Products Searched": FirebaseAnalytics.AnalyticsEventSearch]
    
    static let mappedKeys = ["products": FirebaseAnalytics.AnalyticsParameterItems,
                             "category": FirebaseAnalytics.AnalyticsParameterItemCategory,
                             "product_id": FirebaseAnalytics.AnalyticsParameterItemID,
                             "name": FirebaseAnalytics.AnalyticsParameterItemName,
                             "brand": FirebaseAnalytics.AnalyticsParameterItemBrand,
                             "price": FirebaseAnalytics.AnalyticsParameterPrice,
                             "quantity": FirebaseAnalytics.AnalyticsParameterQuantity,
                             "query": FirebaseAnalytics.AnalyticsParameterSearchTerm,
                             "shipping": FirebaseAnalytics.AnalyticsParameterShipping,
                             "tax": FirebaseAnalytics.AnalyticsParameterTax,
                             "total": FirebaseAnalytics.AnalyticsParameterValue,
                             "revenue": FirebaseAnalytics.AnalyticsParameterValue,
                             "order_id": FirebaseAnalytics.AnalyticsParameterTransactionID,
                             "currency": FirebaseAnalytics.AnalyticsParameterCurrency]
    
}
