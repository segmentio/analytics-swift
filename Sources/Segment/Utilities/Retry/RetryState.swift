import Foundation

public struct RetryState: Codable {
    public var pipelineState: PipelineState
    public var waitUntilTime: TimeInterval?
    public var globalRetryCount: Int
    public var batchMetadata: [String: BatchMetadata]

    public init(
        pipelineState: PipelineState = .ready,
        waitUntilTime: TimeInterval? = nil,
        globalRetryCount: Int = 0,
        batchMetadata: [String: BatchMetadata] = [:]
    ) {
        self.pipelineState = pipelineState
        self.waitUntilTime = waitUntilTime
        self.globalRetryCount = globalRetryCount
        self.batchMetadata = batchMetadata
    }

    public func isRateLimited(currentTime: TimeInterval) -> Bool {
        guard pipelineState == .rateLimited else { return false }
        guard let waitTime = waitUntilTime else { return false }
        return currentTime < waitTime
    }
}

public struct BatchMetadata: Codable {
    public var failureCount: Int
    public var nextRetryTime: TimeInterval?
    public var firstFailureTime: TimeInterval?

    public init(
        failureCount: Int = 0,
        nextRetryTime: TimeInterval? = nil,
        firstFailureTime: TimeInterval? = nil
    ) {
        self.failureCount = failureCount
        self.nextRetryTime = nextRetryTime
        self.firstFailureTime = firstFailureTime
    }

    public func shouldRetry(currentTime: TimeInterval) -> Bool {
        guard let nextRetry = nextRetryTime else { return true }
        return currentTime >= nextRetry
    }

    public func exceedsMaxDuration(currentTime: TimeInterval, maxDuration: TimeInterval) -> Bool {
        guard let firstFailure = firstFailureTime else { return false }
        return (currentTime - firstFailure) > maxDuration
    }
}
