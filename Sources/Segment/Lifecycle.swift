//
//  LifecycleEvents.swift
//  Segment
//
//  Created by Brandon Sneed on 12/8/20.
//

import Foundation

#if os(iOS)
import UIKit

protocol iOSLifecycle {
    func applicationWillEnterForeground(application: UIApplication)
}
#endif
