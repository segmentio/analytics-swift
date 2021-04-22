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
        let config = Configuration(writeKey: "WRITE_KEY")
            .flushAt(3)
            .trackApplicationLifecycleEvents(true)
            .flushInterval(10)
        
        let analytics = Analytics(configuration: config)
        self.analytics = analytics
        
        analytics.add(plugin: AfterPlugin(name: "AfterPlugin_EndOfTimeline", analytics: analytics))

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) {
            analytics.identify(userId: "Segment Spec: Identify")
            analytics.track(name: "Segment Spec: Track", properties: MyTraits(email: "info@segment.com"))
            analytics.screen(screenTitle: "Segment Spec: Screen")
            analytics.group(groupId: "Segment Spec: Group")
            //analytics.alias(newId: "Segment Spec: Alias")
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
