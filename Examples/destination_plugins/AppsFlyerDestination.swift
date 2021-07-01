//
//  AppsFlyerDestination.swift
//
//  Created by Alan Charles on 6/22/21.
//
// NOTE: You can see this plugin in use in the DestinationsExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.
//
// AppsFlyer SPM package can be found here: https://github.com/adjust/ios_sdk
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
//
// *** To Implement Deep Linking functionality reference: https://support.appsflyer.com/hc/en-us/articles/208874366 ****

import Foundation
import Segment
import AppsFlyerLib
import  UIKit

private struct AppsFlyerSettings: Codable {
    let appsFlyerDevKey: String
    let appleAppID: String
    let trackAttributionData: Bool?
}

@objc
class AppsFlyerDestination: UIResponder, DestinationPlugin, RemoteNotifications, iOSLifecycle  {
    
    let timeline: Timeline = Timeline()
    let type: PluginType = .destination
    let name: String
    var analytics: Analytics?
    
    fileprivate var settings: AppsFlyerSettings? = nil
    
    required init(name: String) {
        self.name = name
        analytics?.track(name: "AppsFlyer Loaded")
    }
    
    public func update(settings: Settings) {
        
        guard let settings: AppsFlyerSettings = settings.integrationSettings(name: "AppsFlyer") else { return }
        self.settings = settings
        
        AppsFlyerLib.shared().appsFlyerDevKey = settings.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = settings.appleAppID
        
        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60) //OPTIONAL
        AppsFlyerLib.shared().isDebug = true //OPTIONAL
        AppsFlyerLib.shared().deepLinkDelegate = self //OPTIONAL
        
        let trackAttributionData = settings.trackAttributionData
        
        if trackAttributionData ?? false {
            AppsFlyerLib.shared().delegate = self
        }
        
        func applicationDidBecomeActive(application: UIApplication) {
            AppsFlyerLib.shared().start()
        }
        
        func openURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) {
            AppsFlyerLib.shared().handleOpen(url, options: options)
        }
        
        func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {
            AppsFlyerLib.shared().handlePushNotification(userInfo)
        }
    }
    
    public func identify(event: IdentifyEvent) -> IdentifyEvent? {
        if let userId = event.userId, userId.count > 0 {
            AppsFlyerLib.shared().customerUserID = userId
        }
        
        if let traits = event.traits?.dictionaryValue {
            var aFTraits: [AnyHashable: Any] = [:]
            
            if let email = traits["email"] as? String {
                aFTraits["email"] = email
            }
            
            if let firstName = traits["firstName"] as? String {
                aFTraits["firstName"] = firstName
            }
            
            if let lastName = traits["lastName"] as? String {
                aFTraits["lastName"] = lastName
            }
            
            if traits["currencyCode"] != nil {
                AppsFlyerLib.shared().currencyCode = traits["currencyCode"] as? String
            }
            
            AppsFlyerLib.shared().customData = aFTraits
        }
        
        return event
    }
    
    public func track(event: TrackEvent) -> TrackEvent? {
        
        var properties = event.properties?.dictionaryValue
        
        let revenue: Double? = extractRevenue(key: "revenue", from: properties)
        let currency: String? = extractCurrency(key: "currency", from: properties, withDefault: "USD")
        
        if let af_revenue = revenue, let af_currency = currency {
            properties?["af_revenue"] = af_revenue
            properties?["af_currency"] = af_currency
            
            properties?.removeValue(forKey: "revenue")
            properties?.removeValue(forKey: "currency")
            
            AppsFlyerLib.shared().logEvent(event.event, withValues: properties)
            
        } else {
            AppsFlyerLib.shared().logEvent(event.event, withValues: properties)
        }
        
        return event
    }
}

//MARK: - UserActivities Protocol

extension AppsFlyerDestination: UserActivities {
    func continueUserActivity(_ activity: NSUserActivity) {
        AppsFlyerLib.shared().continue(activity, restorationHandler: nil)
    }
}


//MARK: - Support methods
// matches existing AppsFlyer Destination to set revenue and currency as reserved properties
// https://github.com/AppsFlyerSDK/segment-appsflyer-ios/blob/master/segment-appsflyer-ios/Classes/SEGAppsFlyerIntegration.m#L148
extension AppsFlyerDestination {
    internal func extractRevenue(key: String, from properties: [String: Any]?) -> Double? {
        
        guard let revenueProperty =  properties?[key] as? Double else {return nil}
        
        if let revenue = properties?["revenue"] as? String  {
            let revenueProperty = Double(revenue)
            return revenueProperty
            
        }
        return revenueProperty
    }
    
    
    internal func extractCurrency(key: String, from properties: [String: Any]?, withDefault value: String? = nil) -> String? {
        
        if let currency = properties?[key] as? String {
            return currency
        }
        
        return "USD"
    }
    
}

// MARK: - AppsFlyer Lib Delegate conformance

extension AppsFlyerDestination: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        guard let firstLaunchFlag = conversionInfo["is_first_launch"] as? Int else {
            return
        }
        
        guard let status = conversionInfo["af_status"] as? String else {
            return
        }
        
        if (firstLaunchFlag == 1) {
            if (status == "Non-organic") {
                if let mediaSource = conversionInfo["media_source"] , let campaign = conversionInfo["campaign"]{
                    
                    let campaign: [String: Any] = [
                        "source": mediaSource,
                        "name": campaign
                    ]
                    
                    let properties: [String: Any] = [
                        "provider": "AppsFlyer",
                        "campaign": campaign
                    ]
                    
                    analytics?.track(name: "Install Attributed", properties: properties)
                    
                }
            } else {
                analytics?.track(name: "Organic Install")
            }
        } else {
            analytics?.log(message: "Not First Launch")
        }
        
    }
    
    func onConversionDataFail(_ error: Error) {
        analytics?.log(message: "\(error)")
    }
    
    
    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        
        if let media_source = attributionData["media_source"] , let campaign = attributionData["campaign"],
           let referrer  = attributionData["http_referrer"] {
            
            let campaign: [String: Any] = [
                "source": media_source,
                "name": campaign,
                "url": referrer
            ]
            
            let properties: [String: Any] = [
                "provider": "AppsFlyer",
                "campaign": campaign
            ]
            
            analytics?.track(name: "Deep Link Opened", properties: properties)
        }
    }
    
    
    func onAppOpenAttributionFailure(_ error: Error) {
        analytics?.log(message: "\(error)")
    }
}

//MARK: - AppsFlyer DeepLink Delegate conformance

extension AppsFlyerDestination: DeepLinkDelegate, UIApplicationDelegate {
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        print(result)
        switch result.status {
        case .notFound:
            analytics?.log(message: "AppsFlyer: Deep link not found")
            return
        case .failure:
            analytics?.log(message: "AppsFlyer: Deep link failure!")
            return
        case .found:
            analytics?.log(message: "AppsFlyer Deep link found")
        }
        
        guard let deepLinkObj:DeepLink = result.deepLink else { return }
        
        if (deepLinkObj.isDeferred == true) {
            
            let campaign: [String: Any] = [
                "source": deepLinkObj.mediaSource ?? "",
                "name": deepLinkObj.campaign ?? "",
                "product": deepLinkObj.deeplinkValue ?? ""
            ]
            
            let properties: [String: Any] = [
                "provider": "AppsFlyer",
                "campaign": campaign
            ]
            
            analytics?.track(name: "Deferred Deep Link", properties: properties)
            
        } else {
            
            let campaign: [String: Any] = [
                "source": deepLinkObj.mediaSource ?? "",
                "name": deepLinkObj.campaign ?? "",
                "product": deepLinkObj.deeplinkValue ?? ""
            ]
            
            let properties: [String: Any] = [
                "provider": "AppsFlyer",
                "campaign": campaign
            ]
            
            analytics?.track(name: "Direct Deep Link", properties: properties)
            
        }
        
        //Logic to grab AppsFlyer's deep link value to instantiate correct VC
        //        guard let productNameStr = deepLinkObj.deeplinkValue else {
        //            print("Could not extract deep_link_value from deep link object")
        //            return
        //        }
        
        //implement your own logic to open the correct screen/content
        //        walkToSceneWithParams(product: productNameStr, deepLinkObj: deepLinkObj)
    }
    
    
    // User logic for opening Deep Links
    //    fileprivate func walkToSceneWithParams(product: String, deepLinkObj: DeepLink) {
    //        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    //        UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: true, completion: nil)
    //
    //        let destVC = "product_vc"
    //        if let newVC = storyBoard.instantiateVC(withIdentifier: destVC) {
    //
    //            print("[AFSDK] AppsFlyer routing to section: \(destVC)")
    //            newVC.deepLinkData = deepLinkObj
    //
    //            UIApplication.shared.windows.first?.rootViewController?.present(newVC, animated: true, completion: nil)
    //        } else {
    //            print("[AFSDK] AppsFlyer: could not find section: \(destVC)")
    //        }
    //    }
}

//MARK: - UI StoryBoard Extension; Deep Linking

//Aditonal logic for Deep Linking
//extension UIStoryboard {
//    func instantiateVC(withIdentifier identifier: String) -> DLViewController? {
//        // "identifierToNibNameMap" – dont change it. It is a key for searching IDs
//        if let identifiersList = self.value(forKey: "identifierToNibNameMap") as? [String: Any] {
//            if identifiersList[identifier] != nil {
//                return self.instantiateViewController(withIdentifier: identifier) as? DLViewController
//            }
//        }
//        return nil
//    }
//}
