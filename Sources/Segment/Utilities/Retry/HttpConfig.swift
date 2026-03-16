import Foundation

public struct RateLimitConfig: Codable {
    public var enabled: Bool
    public var maxRetryCount: Int
    public var maxRetryInterval: Int

    public init(
        enabled: Bool = false,
        maxRetryCount: Int = 100,
        maxRetryInterval: Int = 300
    ) {
        self.enabled = enabled
        self.maxRetryCount = maxRetryCount
        self.maxRetryInterval = maxRetryInterval
    }

    public func validated() -> RateLimitConfig {
        return RateLimitConfig(
            enabled: enabled,
            maxRetryCount: max(0, min(maxRetryCount, 1000)),
            maxRetryInterval: max(1, min(maxRetryInterval, 3600))
        )
    }
}

public struct BackoffConfig: Codable {
    public var enabled: Bool
    public var maxRetryCount: Int
    public var baseBackoffInterval: Double
    public var maxBackoffInterval: Int
    public var maxTotalBackoffDuration: Int
    public var jitterPercent: Int
    public var default4xxBehavior: RetryBehavior
    public var default5xxBehavior: RetryBehavior
    public var unknownCodeBehavior: RetryBehavior
    public var statusCodeOverrides: [Int: RetryBehavior]

    public init(
        enabled: Bool = false,
        maxRetryCount: Int = 100,
        baseBackoffInterval: Double = 0.5,
        maxBackoffInterval: Int = 300,
        maxTotalBackoffDuration: Int = 43200,
        jitterPercent: Int = 10,
        default4xxBehavior: RetryBehavior = .drop,
        default5xxBehavior: RetryBehavior = .retry,
        unknownCodeBehavior: RetryBehavior = .drop,
        statusCodeOverrides: [Int: RetryBehavior] = [
            408: .retry,
            410: .retry,
            429: .retry,
            460: .retry,
            501: .drop,
            505: .drop
        ]
    ) {
        self.enabled = enabled
        self.maxRetryCount = maxRetryCount
        self.baseBackoffInterval = baseBackoffInterval
        self.maxBackoffInterval = maxBackoffInterval
        self.maxTotalBackoffDuration = maxTotalBackoffDuration
        self.jitterPercent = jitterPercent
        self.default4xxBehavior = default4xxBehavior
        self.default5xxBehavior = default5xxBehavior
        self.unknownCodeBehavior = unknownCodeBehavior
        self.statusCodeOverrides = statusCodeOverrides
    }

    public func validated() -> BackoffConfig {
        let validOverrides = statusCodeOverrides.filter { (code, _) in
            code >= 100 && code <= 599
        }

        return BackoffConfig(
            enabled: enabled,
            maxRetryCount: max(0, min(maxRetryCount, 1000)),
            baseBackoffInterval: max(0.1, min(baseBackoffInterval, 60.0)),
            maxBackoffInterval: max(1, min(maxBackoffInterval, 3600)),
            maxTotalBackoffDuration: max(0, min(maxTotalBackoffDuration, 604800)),
            jitterPercent: max(0, min(jitterPercent, 50)),
            default4xxBehavior: default4xxBehavior,
            default5xxBehavior: default5xxBehavior,
            unknownCodeBehavior: unknownCodeBehavior,
            statusCodeOverrides: validOverrides
        )
    }
}

public struct HttpConfig: Codable {
    public var rateLimitConfig: RateLimitConfig
    public var backoffConfig: BackoffConfig

    public init(
        rateLimitConfig: RateLimitConfig = RateLimitConfig(),
        backoffConfig: BackoffConfig = BackoffConfig()
    ) {
        self.rateLimitConfig = rateLimitConfig.validated()
        self.backoffConfig = backoffConfig.validated()
    }

    // Custom Codable implementation for defensive deserialization
    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rateLimitConfig = try container.decodeIfPresent(RateLimitConfig.self, forKey: .rateLimitConfig) ?? RateLimitConfig()
            let backoffConfig = try container.decodeIfPresent(BackoffConfig.self, forKey: .backoffConfig) ?? BackoffConfig()

            // Validate during deserialization
            self.rateLimitConfig = rateLimitConfig.validated()
            self.backoffConfig = backoffConfig.validated()
        } catch {
            // Any error -> return safe defaults
            self.rateLimitConfig = RateLimitConfig()
            self.backoffConfig = BackoffConfig()
        }
    }

    enum CodingKeys: String, CodingKey {
        case rateLimitConfig
        case backoffConfig
    }
}
