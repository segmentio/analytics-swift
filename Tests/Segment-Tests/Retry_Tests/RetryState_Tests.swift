import XCTest
@testable import Segment

class RetryState_Tests: XCTestCase {
    func testDefaultRetryState() {
        let state = RetryState()
        XCTAssertEqual(state.pipelineState, .ready)
        XCTAssertNil(state.waitUntilTime)
        XCTAssertEqual(state.globalRetryCount, 0)
        XCTAssertTrue(state.batchMetadata.isEmpty)
    }

    func testIsRateLimited() {
        let futureTime = Date().timeIntervalSince1970 + 60
        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: futureTime
        )

        let currentTime = Date().timeIntervalSince1970
        XCTAssertTrue(state.isRateLimited(currentTime: currentTime))
    }

    func testBatchMetadataShouldRetry() {
        let metadata = BatchMetadata(
            failureCount: 1,
            nextRetryTime: Date().timeIntervalSince1970 - 10
        )
        XCTAssertTrue(metadata.shouldRetry(currentTime: Date().timeIntervalSince1970))
    }

    func testFakeTimeProvider() {
        let fake = FakeTimeProvider(currentTime: 1000)
        XCTAssertEqual(fake.now(), 1000)

        fake.setTime(2000)
        XCTAssertEqual(fake.now(), 2000)
    }
}
