//
//  iOSUtils.swift
//  Segment
//
//  Created by Brandon Sneed on 2/24/21.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)

import UIKit

func insertPlatformContextData(context: inout [String: Any]) {
    let device = UIDevice.current
    
    // TODO: handle "token"
    
    context["device"] = [
        "manufacturer": "Apple",
        "type": "ios",
        "model": "",
        "id": device.identifierForVendor?.uuidString ?? ""
    ]
    
    context["os"] = [
        "name": device.systemName,
        "version": device.systemVersion
    ]
    
    let screen = UIScreen.main.bounds.size
    context["screen"] = [
        "width": screen.width,
        "height": screen.height
    ]
}

#endif
