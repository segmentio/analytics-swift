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

        return state
    }
}
