//
//  ResultViewController.swift
//  SegmentExtensionsExample
//
//  Created by Alan Charles on 8/10/21.
//

import UIKit
import AuthenticationServices

class ResultViewController: UIViewController {
    var analytics = UIApplication.shared.delegate?.analytics
    
    @IBOutlet weak var userIdentifierLabel: UILabel!
    @IBOutlet weak var givenNameLabel: UILabel!
    @IBOutlet weak var familyNameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var signOutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        userIdentifierLabel.text = KeychainItem.currentUserIdentifier
    }
    
    @IBAction func signOutButtonPressed(_ sender: UIButton!) {
        KeychainItem.deleteUserIdentifierFromKeychain()
        
        userIdentifierLabel.text = ""
        givenNameLabel.text = ""
        familyNameLabel.text = ""
        emailLabel.text = ""
        
        DispatchQueue.main.async {
            self.showLoginViewController()
        }
        
        analytics?.track(name: "Logged Out")
    }
}

