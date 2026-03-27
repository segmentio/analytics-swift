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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.maxRetryCount = try container.decodeIfPresent(Int.self, forKey: .maxRetryCount) ?? 100
        self.maxRetryInterval = try container.decodeIfPresent(Int.self, forKey: .maxRetryInterval) ?? 300
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

    enum CodingKeys: String, CodingKey {
        case enabled, maxRetryCount, baseBackoffInterval, maxBackoffInterval
        case maxTotalBackoffDuration, jitterPercent
        case default4xxBehavior, default5xxBehavior, unknownCodeBehavior
        case statusCodeOverrides
    }

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.maxRetryCount = try container.decodeIfPresent(Int.self, forKey: .maxRetryCount) ?? 100
        self.baseBackoffInterval = try container.decodeIfPresent(Double.self, forKey: .baseBackoffInterval) ?? 0.5
        self.maxBackoffInterval = try container.decodeIfPresent(Int.self, forKey: .maxBackoffInterval) ?? 300
        self.maxTotalBackoffDuration = try container.decodeIfPresent(Int.self, forKey: .maxTotalBackoffDuration) ?? 43200
        self.jitterPercent = try container.decodeIfPresent(Int.self, forKey: .jitterPercent) ?? 10
        self.default4xxBehavior = try container.decodeIfPresent(RetryBehavior.self, forKey: .default4xxBehavior) ?? .drop
        self.default5xxBehavior = try container.decodeIfPresent(RetryBehavior.self, forKey: .default5xxBehavior) ?? .retry
        self.unknownCodeBehavior = try container.decodeIfPresent(RetryBehavior.self, forKey: .unknownCodeBehavior) ?? .drop

        // statusCodeOverrides comes from JSON with string keys like "400": "retry"
        let defaultOverrides: [Int: RetryBehavior] = [
            408: .retry, 410: .retry, 429: .retry, 460: .retry,
            501: .drop, 505: .drop
        ]
        if let stringKeyed = try container.decodeIfPresent([String: RetryBehavior].self, forKey: .statusCodeOverrides) {
            var result = [Int: RetryBehavior]()
            for (key, value) in stringKeyed {
                if let code = Int(key) {
                    result[code] = value
                }
            }
            self.statusCodeOverrides = result
        } else {
            self.statusCodeOverrides = defaultOverrides
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(maxRetryCount, forKey: .maxRetryCount)
        try container.encode(baseBackoffInterval, forKey: .baseBackoffInterval)
        try container.encode(maxBackoffInterval, forKey: .maxBackoffInterval)
        try container.encode(maxTotalBackoffDuration, forKey: .maxTotalBackoffDuration)
        try container.encode(jitterPercent, forKey: .jitterPercent)
        try container.encode(default4xxBehavior, forKey: .default4xxBehavior)
        try container.encode(default5xxBehavior, forKey: .default5xxBehavior)
        try container.encode(unknownCodeBehavior, forKey: .unknownCodeBehavior)
        let stringKeyed = Dictionary(uniqueKeysWithValues: statusCodeOverrides.map { (String($0.key), $0.value) })
        try container.encode(stringKeyed, forKey: .statusCodeOverrides)
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rl = try container.decodeIfPresent(RateLimitConfig.self, forKey: .rateLimitConfig) ?? RateLimitConfig()
        let bo = try container.decodeIfPresent(BackoffConfig.self, forKey: .backoffConfig) ?? BackoffConfig()
        self.rateLimitConfig = rl
        self.backoffConfig = bo
    }
}
