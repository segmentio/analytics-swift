//
//  LifecycleEvents.swift
//  Segment
//
//  Created by Cody Garvin on 12/4/20.
//

import Foundation
#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit

class iOSLifeCycleEvents: Extension {
    let type: ExtensionType
    let name: String
    
    var analytics: Analytics? = nil
    
    private var application: UIApplication

    required init(type: ExtensionType, name: String) {
        self.type = .before
        self.name = name
        application = UIApplication.shared
        
        setupListeners()
    }
    
    func setupListeners() {
        // do all your subscription to lifecycle shit here
        // .. listener ends up calling appicationDidFinishLaunching
    }
    
    func applicationDidFinishLaunching(notification: Notification) {
        // ... deconstruct it ...
        
        analytics?.extensions.apply { (ext) in
            if let validExt = ext as? iOSLifecycle {
                validExt.applicationWillEnterForeground(application: application)
            }
        }
    }
    
}

#endif
