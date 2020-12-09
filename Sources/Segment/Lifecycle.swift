//
//  LifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 12/8/20.
//

import Foundation

#if os(iOS)
import UIKit

protocol iOSLifecycle {
    func applicationDidEnterBackground(application: UIApplication)
    func applicationWillEnterForeground(application: UIApplication)
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func applicationDidBecomeActive(application: UIApplication)
    func applicationWillResignActive(application: UIApplication)
    func applicationDidReceiveMemoryWarning(application: UIApplication)
    func applicationWillTerminate(application: UIApplication)
    func applicationSignificantTimeChange(application: UIApplication)
    func applicationBackgroundRefreshDidChange(application: UIApplication, refreshStatus: UIBackgroundRefreshStatus)
}
#endif
