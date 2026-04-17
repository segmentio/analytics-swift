import XCTest
@testable import Segment

class HttpConfig_Tests: XCTestCase {
    func testDefaultHttpConfig() {
        let config = HttpConfig()
        XCTAssertFalse(config.rateLimitConfig.enabled)
        XCTAssertFalse(config.backoffConfig.enabled)
    }

    func testRateLimitConfigValidation() {
        let config = RateLimitConfig(maxRetryCount: 5000, maxRetryInterval: 10000)
        let validated = config.validated()

        XCTAssertEqual(validated.maxRetryCount, 1000) // clamped
        XCTAssertEqual(validated.maxRetryInterval, 3600) // clamped
    }

    func testBackoffConfigValidation() {
        let config = BackoffConfig(
            jitterPercent: 100,
            statusCodeOverrides: [99: .retry, 408: .retry, 600: .drop]
        )
        let validated = config.validated()

        XCTAssertEqual(validated.jitterPercent, 50) // clamped
        XCTAssertNil(validated.statusCodeOverrides[99]) // filtered
        XCTAssertNil(validated.statusCodeOverrides[600]) // filtered
        XCTAssertEqual(validated.statusCodeOverrides[408], .retry) // kept
    }

    func testRateLimitConfigValidation_ClampsMaxRetryCountToMax() {
        let config = RateLimitConfig(maxRetryCount: 2000)
        let validated = config.validated()

        XCTAssertEqual(validated.maxRetryCount, 1000) // clamped to max
    }

    func testRateLimitConfigValidation_ClampsMaxRetryIntervalToMax() {
        let config = RateLimitConfig(maxRetryInterval: 5000)
        let validated = config.validated()

        XCTAssertEqual(validated.maxRetryInterval, 3600) // clamped to 1 hour
    }

    func testRateLimitConfigValidation_ClampsMaxRetryIntervalToMin() {
        let config = RateLimitConfig(maxRetryInterval: 0)
        let validated = config.validated()

        XCTAssertEqual(validated.maxRetryInterval, 1) // clamped to 1 second
    }

    func testBackoffConfigValidation_ClampsMaxRetryCountToMax() {
        let config = BackoffConfig(maxRetryCount: 2000)
        let validated = config.validated()

        XCTAssertEqual(validated.maxRetryCount, 1000) // clamped to max
    }

    func testBackoffConfigValidation_ClampsBaseBackoffIntervalToMax() {
        let config = BackoffConfig(baseBackoffInterval: 100.0)
        let validated = config.validated()

        XCTAssertEqual(validated.baseBackoffInterval, 60.0) // clamped to 60 seconds
    }

    func testBackoffConfigValidation_ClampsBaseBackoffIntervalToMin() {
        let config = BackoffConfig(baseBackoffInterval: 0.05)
        let validated = config.validated()

        XCTAssertEqual(validated.baseBackoffInterval, 0.1) // clamped to 100ms
    }

    func testBackoffConfigValidation_ClampsJitterPercent() {
        let config = BackoffConfig(jitterPercent: 100)
        let validated = config.validated()

        XCTAssertEqual(validated.jitterPercent, 50) // clamped to 50%
    }

    func testBackoffConfigValidation_FiltersInvalidStatusCodes() {
        let config = BackoffConfig(
            statusCodeOverrides: [
                99: .retry,   // Below valid range
                408: .retry,  // Valid
                600: .retry   // Above valid range
            ]
        )
        let validated = config.validated()

        XCTAssertNil(validated.statusCodeOverrides[99])
        XCTAssertNil(validated.statusCodeOverrides[600])
        XCTAssertEqual(validated.statusCodeOverrides[408], .retry)
    }

    func testBackoffConfigValidation_HandlesNegativeValues() {
        let config = BackoffConfig(
            maxRetryCount: -10,
            baseBackoffInterval: -1.0,
            jitterPercent: -5
        )
        let validated = config.validated()

        XCTAssertEqual(validated.maxRetryCount, 0) // clamped to 0
        XCTAssertEqual(validated.baseBackoffInterval, 0.1) // clamped to min
        XCTAssertEqual(validated.jitterPercent, 0) // clamped to 0
    }

    // MARK: - Codable tests

    func testRateLimitConfigDecodesFromPartialJSON() throws {
        let json = """
        { "enabled": true, "maxRetryCount": 5 }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(RateLimitConfig.self, from: json)
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxRetryCount, 5)
        XCTAssertEqual(config.maxRetryInterval, 300) // default
    }

    func testRateLimitConfigDecodesFromEmptyJSON() throws {
        let json = "{}".data(using: .utf8)!
        let config = try JSONDecoder().decode(RateLimitConfig.self, from: json)
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.maxRetryCount, 100)
        XCTAssertEqual(config.maxRetryInterval, 300)
    }

    func testBackoffConfigDecodesFromPartialJSON() throws {
        let json = """
        {
            "enabled": true,
            "maxRetryCount": 3,
            "baseBackoffInterval": 1.0,
            "statusCodeOverrides": { "408": "retry", "501": "drop" }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(BackoffConfig.self, from: json)
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxRetryCount, 3)
        XCTAssertEqual(config.baseBackoffInterval, 1.0)
        XCTAssertEqual(config.maxBackoffInterval, 300) // default
        XCTAssertEqual(config.statusCodeOverrides[408], .retry)
        XCTAssertEqual(config.statusCodeOverrides[501], .drop)
    }

    func testBackoffConfigDecodesFromEmptyJSON() throws {
        let json = "{}".data(using: .utf8)!
        let config = try JSONDecoder().decode(BackoffConfig.self, from: json)
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.maxRetryCount, 100)
        XCTAssertEqual(config.default4xxBehavior, .drop)
        XCTAssertEqual(config.default5xxBehavior, .retry)
        // default overrides when key missing from JSON
        XCTAssertEqual(config.statusCodeOverrides[408], .retry)
        XCTAssertEqual(config.statusCodeOverrides[505], .drop)
    }

    func testBackoffConfigEncodeDecodeRoundTrip() throws {
        let original = BackoffConfig(
            enabled: true,
            maxRetryCount: 10,
            baseBackoffInterval: 2.0,
            maxBackoffInterval: 60,
            maxTotalBackoffDuration: 3600,
            jitterPercent: 20,
            default4xxBehavior: .drop,
            default5xxBehavior: .retry,
            unknownCodeBehavior: .drop,
            statusCodeOverrides: [408: .retry, 501: .drop]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BackoffConfig.self, from: data)

        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.maxRetryCount, original.maxRetryCount)
        XCTAssertEqual(decoded.baseBackoffInterval, original.baseBackoffInterval)
        XCTAssertEqual(decoded.maxBackoffInterval, original.maxBackoffInterval)
        XCTAssertEqual(decoded.jitterPercent, original.jitterPercent)
        XCTAssertEqual(decoded.statusCodeOverrides[408], .retry)
        XCTAssertEqual(decoded.statusCodeOverrides[501], .drop)
    }

    func testHttpConfigDecodesFromPartialJSON() throws {
        let json = """
        {
            "rateLimitConfig": { "enabled": true },
            "backoffConfig": { "enabled": true, "maxRetryCount": 5 }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(HttpConfig.self, from: json)
        XCTAssertTrue(config.rateLimitConfig.enabled)
        XCTAssertTrue(config.backoffConfig.enabled)
        XCTAssertEqual(config.backoffConfig.maxRetryCount, 5)
    }

    func testHttpConfigDecodesFromEmptyJSON() throws {
        let json = "{}".data(using: .utf8)!
        let config = try JSONDecoder().decode(HttpConfig.self, from: json)
        XCTAssertFalse(config.rateLimitConfig.enabled)
        XCTAssertFalse(config.backoffConfig.enabled)
    }

    // MARK: - Validation tests (existing)

    func testHttpConfigAutomaticValidation() {
        let config = HttpConfig(
            rateLimitConfig: RateLimitConfig(
                maxRetryCount: 5000,
                maxRetryInterval: 10000
            ),
            backoffConfig: BackoffConfig(
                jitterPercent: 200
            )
        )

        // Values should be automatically clamped during init
        XCTAssertEqual(config.rateLimitConfig.maxRetryCount, 1000)
        XCTAssertEqual(config.rateLimitConfig.maxRetryInterval, 3600)
        XCTAssertEqual(config.backoffConfig.jitterPercent, 50)
    }
}
