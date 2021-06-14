//
//  AppDelegate.swift
//  DestinationsExample
//
//  Created by Brandon Sneed on 5/27/21.
//

import UIKit
import Segment

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var analytics: Analytics? = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let configuration = Configuration(writeKey: "1234")
            .trackApplicationLifecycleEvents(true)
            .flushInterval(10)
        
        analytics = Analytics(configuration: configuration)
        
        // Add Adjust destination plugin
        analytics?.add(plugin: AdjustDestination(name: "Adjust"))
        
        // Add Amplitude session plugin
        analytics?.add(plugin: AmplitudeSession(name: "Amplitude"))
        
        // Add Mixpanel destination plugin
        analytics?.add(plugin: MixpanelDestination(name: "Mixpanel"))
        
        // Add Flurry destination plugin
        analytics?.add(plugin: FlurryDestination(name: "Flurry"))

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


}

extension UIApplicationDelegate {
    var analytics: Analytics? {
        if let appDelegate = self as? AppDelegate {
            return appDelegate.analytics
        }
        return nil
    }
}

