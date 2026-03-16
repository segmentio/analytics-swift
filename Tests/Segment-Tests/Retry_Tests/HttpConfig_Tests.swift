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
}
