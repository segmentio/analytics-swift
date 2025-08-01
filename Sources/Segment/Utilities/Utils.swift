//
//  Utils.swift
//  Segment
//
//  Created by Brandon Sneed on 5/18/21.
//

import Foundation

#if os(Linux) || os(Windows)
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
    let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    let appSupportURL = urls[0]
    let segmentURL = appSupportURL.appendingPathComponent("segment/\(writeKey)/")
    
    // Handle one-time migration from old locations
    migrateFromOldLocations(writeKey: writeKey, to: segmentURL)
    
    // try to create it, will fail if already exists, nbd.
    // tvOS, watchOS regularly clear out data.
    try? FileManager.default.createDirectory(at: segmentURL, withIntermediateDirectories: true, attributes: nil)
    return segmentURL
}

private func migrateFromOldLocations(writeKey: String, to newLocation: URL) {
    let fm = FileManager.default
    
    // Get the parent of where our new segment directory should live
    let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let newSegmentDir = appSupportURL.appendingPathComponent("segment")
    
    // If segment dir already exists in app support, we're done
    guard !fm.fileExists(atPath: newSegmentDir.path) else { return }
    
    // Only check the old location that was actually used on this platform
    #if (os(iOS) || os(watchOS)) && !targetEnvironment(macCatalyst)
    let oldSearchPath = FileManager.SearchPathDirectory.documentDirectory
    #else
    let oldSearchPath = FileManager.SearchPathDirectory.cachesDirectory
    #endif
    
    guard let oldBaseURL = fm.urls(for: oldSearchPath, in: .userDomainMask).first else { return }
    let oldSegmentDir = oldBaseURL.appendingPathComponent("segment")
    
    guard fm.fileExists(atPath: oldSegmentDir.path) else { return }
    
    do {
        try fm.moveItem(at: oldSegmentDir, to: newSegmentDir)
        Analytics.segmentLog(message: "Migrated analytics data from \(oldSegmentDir.path)", kind: .debug)
    } catch {
        Analytics.segmentLog(message: "Failed to migrate from \(oldSegmentDir.path): \(error)", kind: .error)
    }
}
