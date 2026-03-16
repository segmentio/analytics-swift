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
    let statusCode: Int
    let retryAfterSeconds: Int?
    let batchFile: String
    let currentTime: TimeInterval
}
