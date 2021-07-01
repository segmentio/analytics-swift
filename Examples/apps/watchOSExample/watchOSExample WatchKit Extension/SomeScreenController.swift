//
//  SomeScreenController.swift
//  watchOSExample WatchKit Extension
//
//  Created by Brandon Sneed on 6/25/21.
//

import Foundation
import WatchKit

class SomeScreenController: WKInterfaceController {
    var analytics = WKExtension.shared().delegate?.analytics
    
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        analytics?.screen(screenTitle: "Some Screen Controller")
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

}
