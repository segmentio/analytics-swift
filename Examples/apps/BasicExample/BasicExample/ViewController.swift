//
//  ViewController.swift
//  BasicExample
//
//  Created by Brandon Sneed on 5/21/21.
//

import UIKit
import Segment

class ViewController: UIViewController {
    var analytics: Analytics? {
        return UIApplication.shared.delegate?.analytics
    }
    
    var usage: TimeInterval = 0
    var timer: Timer? = nil

    @IBOutlet weak var eventView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.usage += 1
        }
        
        let outputCapture = OutputPlugin(textView: eventView)
        analytics?.add(plugin: outputCapture)
    }

    @IBAction func trackTapped(_ sender: Any) {
        guard let day = Date().dayOfWeek() else {
            print("we couldn't get the day of the week.  the world has ended. :(")
            return
        }
        
        let props = TrackProperties(dayOfWeek: day)
        analytics?.track(name: "Track Tapped", properties: props)
    }
    
    @IBAction func screenTapped(_ sender: Any) {
        let props = ScreenProperties(appUsage: usage)
        analytics?.screen(title: "Main Screen", category: "Best", properties: props)
    }
    
    @IBAction func identifyTapped(_ sender: Any) {
        let traits = UserTraits(email: "sloth@segment.com", birthday: "09/01/2011", likesPho: true)
        analytics?.identify(userId: "sloth", traits: traits)
    }
    
    @IBAction func groupTapped(_ sender: Any) {
        analytics?.group(groupId: "1234")
    }
    
    @IBAction func flushTapped(_ sender: Any) {
        analytics?.flush()
    }
}

