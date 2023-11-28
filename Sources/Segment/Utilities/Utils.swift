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

/* for dev testing only
#if DEBUG
class TrackingDispatchGroup: CustomStringConvertible {
    internal let group = DispatchGroup()

    var description: String {
        return "DispatchGroup Enters: \(enters), Leaves: \(leaves)"
    }

    var enters: Int = 0
    var leaves: Int = 0
    var current: Int = 0

    func enter() {
        enters += 1
        current += 1
        group.enter()
    }

    func leave() {
        leaves += 1
        current -= 1
        group.leave()
    }

    init() { }

    func wait() {
        group.wait()
    }

    public func notify(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], queue: DispatchQueue, execute work: @escaping @convention(block) () -> Void) {
        group.notify(qos: qos, flags: flags, queue: queue, execute: work)
    }
}
#endif
*/
