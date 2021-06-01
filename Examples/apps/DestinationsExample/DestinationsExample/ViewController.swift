//
//  ViewController.swift
//  DestinationsExample
//
//  Created by Brandon Sneed on 5/27/21.
//

import UIKit
import Segment

class ViewController: UIViewController {
    var analytics = UIApplication.shared.delegate?.analytics
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


    @IBAction func trackAction(_ sender: Any) {
        analytics?.track(name: "test event", properties: ["testValue": 42])
    }
}

