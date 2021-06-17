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


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let configuration = Configuration(writeKey: "<WRITE KEY>")
            .trackApplicationLifecycleEvents(true)
            .flushInterval(10)
        
        analytics = Analytics(configuration: configuration)

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

