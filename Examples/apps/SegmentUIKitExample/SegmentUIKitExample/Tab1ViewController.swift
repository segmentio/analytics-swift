//
//  ViewController.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/8/21.
//

import UIKit

class Tab1ViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func queryAction(_ sender: Any) {
        let alertController = QueryAlertController(title: "I know you like pie", message: "Everyone likes pie", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Yeah, I do", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
}

