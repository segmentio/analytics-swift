import XCTest
@testable import Segment

final class RunOnce_Tests: XCTestCase {

    func testRunExecutesActionOnlyOnce() {
        var count = 0
        let once = RunOnce { count += 1 }

        once.run()
        once.run()
        once.run()

        XCTAssertEqual(count, 1)
    }

    func testConcurrentRunExecutesActionOnlyOnce() {
        @Atomic var count = 0
        let once = RunOnce { _count.mutate { $0 += 1 } }

        DispatchQueue.concurrentPerform(iterations: 1000) { _ in
            once.run()
        }

        XCTAssertEqual(count, 1)
    }

    // A group entered once survives every path trying to leave it.
    func testBalancesDispatchGroupWhenLeftFromMultiplePaths() {
        let group = DispatchGroup()
        group.enter()
        let leaveGroup = RunOnce { group.leave() }

        leaveGroup.run()
        leaveGroup.run()

        XCTAssertEqual(group.wait(timeout: .now() + 1), .success)
    }
}
