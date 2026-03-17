import XCTest
@testable import Segment

class Storage_RetryState_Tests: XCTestCase {
    var storage: Storage!

    func uniqueWriteKey() -> String {
        return "test-\(UUID().uuidString)"
    }

    override func setUp() {
        super.setUp()
        let analytics = Analytics(configuration: Configuration(writeKey: uniqueWriteKey()))
        storage = analytics.storage
    }

    override func tearDown() {
        // Clean up
        storage.hardReset(doYouKnowHowToUseThis: true)
        super.tearDown()
    }

    func testSaveAndLoadRetryState() {
        let state = RetryState(
            pipelineState: .rateLimited,
            waitUntilTime: 12345.0,
            globalRetryCount: 3,
            batchMetadata: ["batch1": BatchMetadata(failureCount: 2)]
        )

        storage.saveRetryState(state)
        let loaded = storage.loadRetryState()

        XCTAssertEqual(loaded.pipelineState, .rateLimited)
        XCTAssertEqual(loaded.waitUntilTime, 12345.0)
        XCTAssertEqual(loaded.globalRetryCount, 3)
        XCTAssertEqual(loaded.batchMetadata.count, 1)
    }

    func testLoadRetryStateReturnsDefaultsWhenMissing() {
        let loaded = storage.loadRetryState()

        XCTAssertEqual(loaded.pipelineState, .ready)
        XCTAssertNil(loaded.waitUntilTime)
        XCTAssertEqual(loaded.globalRetryCount, 0)
        XCTAssertTrue(loaded.batchMetadata.isEmpty)
    }
}
