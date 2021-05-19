//
//  Utils.swift
//  Segment
//
//  Created by Brandon Sneed on 5/18/21.
//

import Foundation

internal var isUnitTesting: Bool = {
    let env = ProcessInfo.processInfo.environment
    let value = (env["XCTestConfigurationFilePath"] != nil)
    return value
}()

internal func exceptionFailure(_ message: String) {
    if isUnitTesting {
        assertionFailure(message)
    } else {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
