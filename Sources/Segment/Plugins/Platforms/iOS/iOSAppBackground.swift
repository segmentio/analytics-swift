//
//  iOSAppBackground.swift
//  Segment
//
//  Created by Cody Garvin on 1/14/21.
//

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit

class iOSAppBackground: PlatformPlugin {
    static var specificName = "Segment_iOSAppBackground"
    
    var type: PluginType
    var name: String
    var analytics: Analytics
    private let backgroundQueue = DispatchQueue(label: "com.segment.queueflush")
    private var taskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    
    required init(name: String, analytics: Analytics) {
        self.name = name
        self.analytics = analytics
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
        plugins.apply { (plugin) in
            if let plugin = plugin as? iOSAppBackground {
                plugin.beginBackgroundTask()
            }
        }
    }
    
    func endBackgroundTask() {
        plugins.apply { (plugin) in
            if let plugin = plugin as? iOSAppBackground {
                plugin.endBackgroundTask()
            }
        }
    }
}

#endif
