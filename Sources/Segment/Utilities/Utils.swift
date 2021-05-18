//
//  Utils.swift
//  Segment
//
//  Created by Brandon Sneed on 5/18/21.
//

import Foundation

internal var isUnitTesting: Bool = {
    let env = ProcessInfo().environment
    let value = (env["XCTestConfigurationFilePath"] != nil)
    return value
}()

internal let _SegmentException = "SegmentException"
internal func exceptionFailure(_ message: String) {
    let args: [CVarArg] = []
    if isUnitTesting {
        NSException.raise(NSExceptionName(_SegmentException), format: message, arguments: getVaList(args))
    } else {
        #if DEBUG
        NSException.raise(NSExceptionName(_SegmentException), format: message, arguments: getVaList(args))
        #endif
    }
}
