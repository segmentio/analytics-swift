//
//  Utils.swift
//  Segment
//
//  Created by Brandon Sneed on 5/18/21.
//

import Foundation

#if os(Linux)
extension DispatchQueue {
    func asyncAndWait(execute workItem: DispatchWorkItem) {
        async {
            workItem.perform()
        }
        workItem.wait()
    }
}

// Linux doesn't have autoreleasepool.
func autoreleasepool(closure: () -> Void) {
    closure()
}
#endif

/// Inquire as to whether we are within a Unit Testing environment.
#if DEBUG
internal var isUnitTesting: Bool = {
    // this will work on apple platforms, but fail on linux.
    if NSClassFromString("XCTestCase") != nil {
        return true
    }
    // this will work on linux and apple platforms, but not in anything with a UI
    // because XCTest doesn't come into the call stack till much later.
    let matches = Thread.callStackSymbols.filter { line in
        return line.contains("XCTest") || line.contains("xctest")
    }
    if matches.count > 0 {
        return true
    }
    // this will work on CircleCI to correctly detect test running.
    if ProcessInfo.processInfo.environment["CIRCLE_WORKFLOW_WORKSPACE_ID"] != nil {
        return true
    }
    // couldn't see anything that indicated we were testing.
    return false
}()
#endif

internal var isAppExtension: Bool = {
    if Bundle.main.bundlePath.hasSuffix(".appex") {
        return true
    }
    return false
}()

internal func exceptionFailure(_ message: String) {
    #if DEBUG
    assertionFailure(message)
    #endif
}

internal protocol Flattenable {
    func flattened() -> Any?
}

extension Optional: Flattenable {
    internal func flattened() -> Any? {
        switch self {
        case .some(let x as Flattenable): return x.flattened()
        case .some(let x): return x
        case .none: return nil
        }
    }
}

internal func eventStorageDirectory(writeKey: String) -> URL {
    #if (os(iOS) || os(watchOS)) && !targetEnvironment(macCatalyst)
    let searchPathDirectory = FileManager.SearchPathDirectory.documentDirectory
    #else
    let searchPathDirectory = FileManager.SearchPathDirectory.cachesDirectory
    #endif
    
    let urls = FileManager.default.urls(for: searchPathDirectory, in: .userDomainMask)
    let docURL = urls[0]
    let segmentURL = docURL.appendingPathComponent("segment/\(writeKey)/")
    // try to create it, will fail if already exists, nbd.
    // tvOS, watchOS regularly clear out data.
    try? FileManager.default.createDirectory(at: segmentURL, withIntermediateDirectories: true, attributes: nil)
    return segmentURL
}
