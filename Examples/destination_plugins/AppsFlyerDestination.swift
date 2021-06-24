//
//  File.swift
//  
//
//  Created by Alan Charles on 6/22/21.
//

import Foundation
import Segment
import AppsFlyerLib

 
internal struct AppsFlyerSettings: Codable {
    let appsFlyerDevKey: String
    let appleAppID: String
    let trackAttributionData: Bool?
}

@objc
class AppsFlyerDestination: NSObject, DestinationPlugin {
    
    let timeline: Timeline = Timeline()
    let type: PluginType = .destination
    let name: String
    var analytics: Analytics?
    
    internal var settings: AppsFlyerSettings? = nil
    
     required init(name: String) {
        self.name = name
    }
    
    public func update(settings: Settings) {
                
        guard let settings: AppsFlyerSettings = settings.integrationSettings(name: "AppsFlyer") else {return}
        self.settings = settings
    
       
        AppsFlyerLib.shared().appsFlyerDevKey = settings.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = settings.appleAppID
        AppsFlyerLib.shared().isDebug = true
        AppsFlyerLib.shared().start()

        
        
        
        if let _ = settings.trackAttributionData {
            print(settings.trackAttributionData)
            AppsFlyerLib.shared().delegate = self
            
        }
    }
}


// MARK: - AppsFlyer Delegate conformance

extension AppsFlyerDestination: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        guard let first_launch_flag = conversionInfo["is_first_launch"] as? Int else {
             return
         }
         
         guard let status = conversionInfo["af_status"] as? String else {
             return
         }
        
         if(first_launch_flag == 1) {
             if(status == "Non-organic") {
                 if let media_source = conversionInfo["media_source"] , let campaign = conversionInfo["campaign"]{
                    
                    let campaign: [String: Any] = [
                        "source": media_source,
                        "name": campaign
                    ]
                    
                    let properties: [String: Any] = [
                        "provider": "AppsFlyer",
                        "campaign": campaign
                    ]
                    
                    analytics?.track(name: "Install Attributed", properties: properties)

                 }
             } else {
                analytics?.track(name: "Not an Install")
                 print("This is an organic install.")
             }
         } else {
             print("Not First Launch")
         }
  
    }
    
    func onConversionDataFail(_ error: Error) {
        return
    }
    


}
