//
//  AppDelegate.swift
//  BasicExample
//
//  Created by Brandon Sneed on 5/21/21.
//

import UIKit
import Segment

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var analytics: Analytics? = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let configuration = Configuration(writeKey: "eHitWfSPZKoXF8c6iVb6QRlIPA6P9X8G")
            .trackApplicationLifecycleEvents(true)
            .flushInterval(10)
            .flushAt(2)
        
        Telemetry.shared.flushTimer = 5 * 1000
        Telemetry.shared.enable = true
//        Telemetry.shared.sendErrorLogData = true
//        Telemetry.shared.host = "webhook.site/8d339731-c5a7-45b5-9b82-d545b6e48e6c"
        analytics = Analytics(configuration: configuration)
        
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
