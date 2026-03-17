import Foundation

public protocol TimeProvider {
    func now() -> TimeInterval
}

public class SystemTimeProvider: TimeProvider {
    public init() {}

    public func now() -> TimeInterval {
        return Date().timeIntervalSince1970
    }
}

public class FakeTimeProvider: TimeProvider {
    @Atomic private var currentTime: TimeInterval

    public init(currentTime: TimeInterval = 0) {
        _currentTime = Atomic(wrappedValue: currentTime)
    }

    public func now() -> TimeInterval {
        return currentTime
    }

    public func setTime(_ time: TimeInterval) {
        _currentTime.set(time)
    }

    public func advance(by seconds: TimeInterval) {
        _currentTime.mutate { $0 += seconds }
    }
}
