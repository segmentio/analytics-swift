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
    
    required init(type: ExtensionType) {
        <#code#>
    }
        
    private let application: UIApplication
    init() {
        application = UIApplication.application
    }
}

#endif
