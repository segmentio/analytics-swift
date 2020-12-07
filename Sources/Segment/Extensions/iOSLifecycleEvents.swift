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
    var type: ExtensionType
    private var application: UIApplication

    required init(type: ExtensionType) {
        self.type = .before
        application = UIApplication.shared
    }
}

#endif
