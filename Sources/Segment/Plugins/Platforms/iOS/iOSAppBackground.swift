//
//  iOSAppBackground.swift
//  Segment
//
//  Created by Cody Garvin on 1/14/21.
//

#if os(iOS) || os(tvOS)
import UIKit

class iOSAppBackground: PlatformPlugin {
    static var specificName = "Segment_iOSAppBackground"
    
    let type: PluginType
    let name: String
    var analytics: Analytics?
    private let backgroundQueue = DispatchQueue(label: "com.segment.queueflush")
    private var taskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    
    required init(name: String) {
        self.name = name
        self.type = .utility
    }
    
    fileprivate func beginBackgroundTask() {
        self.endBackgroundTask()
        
        backgroundQueue.sync {
            let application = UIApplication.shared
            taskID = application.beginBackgroundTask(withName: "com.segment.flush") {
                self.endBackgroundTask()
            }
        }
    }
    
    fileprivate func endBackgroundTask() {
        backgroundQueue.sync {
            if taskID.rawValue != 0 {
                let application = UIApplication.shared
                application.endBackgroundTask(taskID)
            }
            
            taskID = UIBackgroundTaskIdentifier(rawValue: 0)
        }
    }
}

extension Analytics {
    func beginBackgroundTask() {
        apply { (plugin) in
            if let plugin = plugin as? iOSAppBackground {
                plugin.beginBackgroundTask()
            }
        }
    }
    
    func endBackgroundTask() {
        apply { (plugin) in
            if let plugin = plugin as? iOSAppBackground {
                plugin.endBackgroundTask()
            }
        }
    }
}

#endif
