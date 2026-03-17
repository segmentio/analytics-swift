import Foundation

public class RetryStateMachine {
    private let config: HttpConfig
    private let timeProvider: TimeProvider

    public init(config: HttpConfig, timeProvider: TimeProvider = SystemTimeProvider()) {
        self.config = config
        self.timeProvider = timeProvider
    }

    private var isLegacyMode: Bool {
        return !config.rateLimitConfig.enabled && !config.backoffConfig.enabled
    }

    public func handleResponse(state: RetryState, response: ResponseInfo) -> RetryState {
        // Success: clear metadata
        if response.statusCode >= 200 && response.statusCode < 300 {
            var newState = state
            newState.pipelineState = .ready
            newState.waitUntilTime = nil
            newState.globalRetryCount = 0
            newState.batchMetadata.removeValue(forKey: response.batchFile)
            return newState
        }

        // 429 rate limiting
        if response.statusCode == 429 && config.rateLimitConfig.enabled {
            let currentTime = response.currentTime
            return handleRateLimitResponse(state: state, response: response, currentTime: currentTime)
        }

        return state
    }

    private func handleRateLimitResponse(
        state: RetryState,
        response: ResponseInfo,
        currentTime: TimeInterval
    ) -> RetryState {
        let waitUntilTime = calculateWaitUntilTime(response.retryAfterSeconds, currentTime: currentTime)

        var newState = state
        newState.pipelineState = .rateLimited
        newState.waitUntilTime = waitUntilTime
        newState.globalRetryCount = state.globalRetryCount + 1
        return newState
    }

    private func calculateWaitUntilTime(_ retryAfterSeconds: Int?, currentTime: TimeInterval) -> TimeInterval {
        let seconds = retryAfterSeconds?.coerceAtLeast(0) ?? config.rateLimitConfig.maxRetryInterval
        let clampedSeconds = min(seconds, config.rateLimitConfig.maxRetryInterval)
        return currentTime + TimeInterval(clampedSeconds)
    }
}

// Extension for Int to match Kotlin's coerceAtLeast
extension Int {
    func coerceAtLeast(_ minValue: Int) -> Int {
        return Swift.max(self, minValue)
    }
}
