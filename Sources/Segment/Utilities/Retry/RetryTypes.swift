import Foundation

// MARK: - Pipeline State

public enum PipelineState: String, Codable {
    case ready
    case rateLimited
}

// MARK: - Retry Behavior

public enum RetryBehavior: String, Codable {
    case retry
    case drop
}

// MARK: - Drop Reason

public enum DropReason: String, Codable {
    case maxRetriesExceeded
    case maxDurationExceeded
    case nonRetryableError
}

// MARK: - Upload Decision

public enum UploadDecision {
    case proceed
    case skipThisBatch
    case skipAllBatches
    case dropBatch(reason: DropReason)
}

// MARK: - Response Info

public struct ResponseInfo {
    public let statusCode: Int
    public let retryAfterSeconds: Int?
    public let batchFile: String
    public let currentTime: TimeInterval

    public init(statusCode: Int, retryAfterSeconds: Int?, batchFile: String, currentTime: TimeInterval) {
        self.statusCode = statusCode
        self.retryAfterSeconds = retryAfterSeconds
        self.batchFile = batchFile
        self.currentTime = currentTime
    }
}
