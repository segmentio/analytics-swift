//
//  AppDelegate.swift
//  MacExample
//
//  Created by Brandon Sneed on 6/16/21.
//

import Cocoa
import Segment

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var analytics: Analytics? = nil
    let blockerFlushPolicy = NetBlockerFlushPolicy()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let configuration = Configuration(writeKey: "<WRITE KEY>")
            .trackApplicationLifecycleEvents(true)
            .flushInterval(10)
            .flushAt(1)
            .errorHandler { error in
                NetBlockerFlushPolicy.networkBlockedHandler(error: error, blockerPolicy: self.blockerFlushPolicy)
            }
        
        analytics = Analytics(configuration: configuration)
        analytics?.add(flushPolicy: blockerFlushPolicy)
        
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { _ in
            self.analytics?.track(name: "test little snitch")
        })
        
        //analytics?.add(plugin: NotificationTracking())
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

extension NSApplicationDelegate {
    var analytics: Analytics? {
        if let appDelegate = self as? AppDelegate {
            return appDelegate.analytics
        }
        return nil
    }
}

