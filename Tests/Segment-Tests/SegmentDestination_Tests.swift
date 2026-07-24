import XCTest
@testable import Segment

final class SegmentDestination_Tests: XCTestCase {

    private final class FakeDataTask: DataTask {
        var state: URLSessionTask.State
        init(state: URLSessionTask.State) { self.state = state }
        func resume() {}
    }

    override func setUpWithError() throws {
        Telemetry.shared.enable = false
    }

    // Non-running tasks are removed and their cleanup closures fire.
    func testCleanupUploadsRemovesNonRunningTasksAndInvokesCleanup() {
        let dest = SegmentDestination()
        let cleanupFired = expectation(description: "cleanup closure ran")

        var info = SegmentDestination.UploadTaskInfo(
            url: nil,
            data: nil,
            task: FakeDataTask(state: .completed),
            cleanup: nil
        )
        info.cleanup = { cleanupFired.fulfill() }
        dest.add(uploadTask: info)
        XCTAssertEqual(dest.pendingUploads, 1)

        dest.cleanupUploads()
        wait(for: [cleanupFired], timeout: 2.0)
        XCTAssertEqual(dest.pendingUploads, 0)
    }

    // Running tasks stay in the queue and their cleanup does not fire.
    func testCleanupUploadsKeepsRunningTasks() {
        let dest = SegmentDestination()
        var cleanupInvocations = 0

        var info = SegmentDestination.UploadTaskInfo(
            url: nil,
            data: nil,
            task: FakeDataTask(state: .running),
            cleanup: nil
        )
        info.cleanup = { cleanupInvocations += 1 }
        dest.add(uploadTask: info)

        dest.cleanupUploads()

        // Drain the main queue so any (unexpected) async cleanup would run.
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1.0)

        XCTAssertEqual(dest.pendingUploads, 1)
        XCTAssertEqual(cleanupInvocations, 0)
    }

    // The cleanup closure must be able to re-enter uploadsQueue accessors
    // without deadlocking — this was the primary crash class being fixed.
    func testCleanupClosureCanReenterUploadsQueueWithoutDeadlock() {
        let dest = SegmentDestination()
        let done = expectation(description: "re-entrant cleanup completed")

        var info = SegmentDestination.UploadTaskInfo(
            url: nil,
            data: nil,
            task: FakeDataTask(state: .completed),
            cleanup: nil
        )
        info.cleanup = { [weak dest] in
            _ = dest?.pendingUploads
            dest?.cleanupUploads()
            done.fulfill()
        }
        dest.add(uploadTask: info)

        dest.cleanupUploads()
        wait(for: [done], timeout: 2.0)
        XCTAssertEqual(dest.pendingUploads, 0)
    }

    // Concurrent cleanup + add calls should not crash or deadlock.
    func testConcurrentCleanupAndAddIsSafe() {
        let dest = SegmentDestination()
        let iterations = 200
        let finished = expectation(description: "concurrent workers done")
        finished.expectedFulfillmentCount = 2

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<iterations {
                let info = SegmentDestination.UploadTaskInfo(
                    url: nil,
                    data: nil,
                    task: FakeDataTask(state: .running),
                    cleanup: nil
                )
                dest.add(uploadTask: info)
            }
            finished.fulfill()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<iterations {
                dest.cleanupUploads()
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 10.0)
    }
}
