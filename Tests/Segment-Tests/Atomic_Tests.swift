import XCTest
@testable import Segment

final class Atomic_Tests: XCTestCase {

    func testAtomicIncrement() {

        @Atomic var counter = 0

        DispatchQueue.concurrentPerform(iterations: 1000) { _ in
            // counter += 1 would fail, because it is expanded to:
            // `let oldValue = queue.sync { counter }`
            // `queue.sync { counter = oldValue + 1 }`
            // And the threads are free to suspend in between the two calls to `queue.sync`.

            _counter.withValue { value in
                value += 1
            }
        }

        XCTAssertEqual(counter, 1000)
    }
}
