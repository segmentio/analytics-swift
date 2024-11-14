//
//  AppDelegate.swift
//  DestinationsExample
//
//  Created by Brandon Sneed on 5/27/21.
//

import UIKit
import Segment
import SegmentAmplitude
import SegmentAppsFlyer
import SegmentFacebook
import SegmentFirebase
import SegmentMixpanel

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    
    var analytics: Analytics? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let configuration = Configuration(writeKey: "EioRQCqLHUECnoSseEguI8GnxOlZTOyX")
            .trackApplicationLifecycleEvents(true)
            .flushInterval(1)
        
        analytics = Analytics(configuration: configuration)
        
        // Add Amplitude session plugin
        analytics?.add(plugin: AmplitudeSession())
        
        // Add Mixpanel destination plugin
        analytics?.add(plugin: MixpanelDestination())
        
        // Add the Firebase destination plugin
        analytics?.add(plugin: FirebaseDestination())
        
        // Add the AppsFlyer destination plugin
        analytics?.add(plugin: AppsFlyerDestination())
        
        // Add the Facebook App Events plugin
        analytics?.add(plugin: FacebookAppEventsDestination())
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Deep Link functionality
    
    // This functionality is needed to forward deep link attribution data with AppsFlyer
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        analytics?.continueUserActivity(userActivity)
        return true
    }
    
    // This functionality is needed to forward deep link attribution data with AppsFlyer
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        analytics?.continueUserActivity(userActivity)
        return true
    }
    
    // This functionality is needed to forward deep link attribution data with AppsFlyer
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        analytics?.openURL(url)
        return true
    }
    
    // This functionality is needed to forward deep link attribution data with AppsFlyer
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        analytics?.openURL(url, options: options)
        return true
    }
    
    // This functionality is needed to forward deep link attribution data with AppsFlyer
    // Report Push Notification attribution data for re-engagements
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // this enables remote notifications for various destinations (appsflyer)
        analytics?.receivedRemoteNotification(userInfo: userInfo)
    }
    
}

extension UIApplicationDelegate {
    var analytics: Analytics? {
        if let appDelegate = self as? AppDelegate {
            return appDelegate.analytics
        }
        return nil
    }
}

