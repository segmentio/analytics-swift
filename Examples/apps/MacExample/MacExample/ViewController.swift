//
//  ViewController.swift
//  MacExample
//
//  Created by Brandon Sneed on 6/16/21.
//

import Cocoa

class ViewController: NSViewController {
    var analytics = NSApplication.shared.delegate?.analytics
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


    @IBAction func trackButton(_ sender: Any) {
        analytics?.track(name: "test event")
    }
}

