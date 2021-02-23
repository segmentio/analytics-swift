//
//  AppDelegate.swift
//  SegmentExample
//
//  Created by Cody Garvin on 12/30/20.
//

import UIKit
import Segment

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var analytics: Analytics? = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        var config = Configuration(writeKey: "8XpdAWa7qJVBJMK8V4FfXQOrnvCzu3Ie")
            .trackApplicationLifecycleEvents(true)
            .flushInterval(10)
        
        let analytics = Analytics(configuration: config)
        self.analytics = analytics
        
        analytics.add(plugin: AfterPlugin(name: "hello", analytics: analytics))
        analytics.add(plugin: SegmentMixPanel(name: "Mixpanel", analytics: analytics))

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) {
            analytics.identify(userId: "Live Demo -- never breaks")
            analytics.track(name: "I once tracked a cougar", properties: MyTraits(email: "Brandon@stinks.com"))
            analytics.screen(screenTitle: "Screened the AppDelegate")
            analytics.group(groupId: "Grouped By ID")
            analytics.alias(newId: "3333")
        }
        
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

struct MyTraits: Codable {
    let email: String?
}
