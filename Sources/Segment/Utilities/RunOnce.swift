//
//  RunOnce.swift
//  Segment
//

import Foundation

/// Wraps an action so it executes at most once, no matter how many code paths
/// (or threads) call `run()`. Used to pair a single `DispatchGroup.enter()`
/// with exactly one `leave()`.
internal final class RunOnce {
    @Atomic private var action: (() -> Void)?

    init(_ action: @escaping () -> Void) {
        _action = Atomic(wrappedValue: action)
    }

    func run() {
        var pending: (() -> Void)? = nil
        _action.mutate { current in
            pending = current
            current = nil
        }
        pending?()
    }
}
