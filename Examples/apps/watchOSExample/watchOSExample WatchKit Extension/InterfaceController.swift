//
//  InterfaceController.swift
//  watchOSExample WatchKit Extension
//
//  Created by Brandon Sneed on 6/24/21.
//

import WatchKit
import Foundation
import Segment


class InterfaceController: WKInterfaceController {

    override func awake(withContext context: Any?) {
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

    @IBAction func trackTapped() {
    }
    
    @IBAction func identifyTapped() {
    }
}
