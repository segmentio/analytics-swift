//
//  AppDelegate.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/8/21.
//

import UIKit
import Segment

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // add console logging plugins to our multiple instances
        Analytics.main.add(plugin: ConsoleLogger(name: "main"))
        Analytics.main.add(plugin: ConsentTracking(name: "consent"))
        Analytics.main.add(plugin: IDFACollection(name: "idfa"))
        Analytics.main.add(plugin: UIKitScreenTracking(name: "autoScreenTracking"))

        Analytics.support.add(plugin: ConsoleLogger(name: "support"))
        Analytics.support.add(plugin: ConsentTracking(name: "consent"))
        
        Analytics.support.track(name: "test event")
        

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

