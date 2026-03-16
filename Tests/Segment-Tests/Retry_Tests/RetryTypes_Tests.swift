import XCTest
@testable import Segment

class RetryTypes_Tests: XCTestCase {
    func testPipelineStateValues() {
        let ready = PipelineState.ready
        let rateLimited = PipelineState.rateLimited
        XCTAssertNotEqual(ready, rateLimited)
    }
}
