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
    private var currentTime: TimeInterval

    public init(currentTime: TimeInterval = 0) {
        self.currentTime = currentTime
    }

    public func now() -> TimeInterval {
        return currentTime
    }

    public func setTime(_ time: TimeInterval) {
        self.currentTime = time
    }

    public func advance(by seconds: TimeInterval) {
        currentTime += seconds
    }
}
