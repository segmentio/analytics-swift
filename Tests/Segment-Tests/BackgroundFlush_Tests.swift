import XCTest
@testable import Segment

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit

private final class FlushCounter: EventPlugin {
    let type = PluginType.utility
    weak var analytics: Analytics?
    @Atomic var count = 0
    func flush() { _count.mutate { $0 += 1 } }
}

// holds the first flush's group open until the test releases it, like an in-flight upload would.
private final class HeldFlush: EventPlugin, FlushCompletion {
    let type = PluginType.utility
    weak var analytics: Analytics?
    @Atomic var group: DispatchGroup? = nil
    @Atomic var held = false
    let entered = DispatchSemaphore(value: 0)

    func flush(group: DispatchGroup) {
        var first = false
        _held.mutate { first = !$0; $0 = true }
        guard first else { return }
        group.enter()
        _group.set(group)
        entered.signal()
    }

    func release() {
        var held: DispatchGroup? = nil
        _group.mutate { held = $0; $0 = nil }
        held?.leave()
    }
}

private final class FakeBackgroundTasks: BackgroundTaskProvider {
    var identifier = UIBackgroundTaskIdentifier(rawValue: 42)
    @Atomic var begun = 0
    @Atomic var ended = [UIBackgroundTaskIdentifier]()
    var expirationHandler: (() -> Void)? = nil
    var onEnd: (() -> Void)? = nil

    func begin(expirationHandler: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
        _begun.mutate { $0 += 1 }
        self.expirationHandler = expirationHandler
        return identifier
    }

    func end(_ identifier: UIBackgroundTaskIdentifier) {
        _ended.mutate { $0.append(identifier) }
        onEnd?()
    }
}

final class BackgroundFlush_Tests: XCTestCase {
    override func setUpWithError() throws {
        Telemetry.shared.enable = false
    }

    // own flush queue and no network, so instances left over from other tests can't delay our flushes.
    private func makeConfiguration() -> Configuration {
        return Configuration(writeKey: uniqueWriteKey())
            .flushInterval(9999)
            .flushQueue(DispatchQueue(label: "com.segment.test.backgroundFlush"))
            .httpSession(RestrictedHTTPSession())
    }

    private func makeAnalytics() -> (Analytics, SegmentDestination) {
        let analytics = Analytics(configuration: makeConfiguration())
        waitUntilStarted(analytics: analytics)
        let destination = analytics.find(pluginType: SegmentDestination.self)!
        return (analytics, destination)
    }

    func testBackgroundingFlushesOnce() {
        let analytics = Analytics(configuration: makeConfiguration()
            .operatingMode(.synchronous))
        let counter = FlushCounter()
        analytics.add(plugin: counter)
        waitUntilStarted(analytics: analytics)

        // deliver the notification to this instance only; posting it globally makes every
        // live instance in the test process flush.
        let monitor = analytics.find(pluginType: iOSLifecycleMonitor.self)!
        monitor.didEnterBackground(notification: NSNotification(name: UIApplication.didEnterBackgroundNotification, object: nil))

        XCTAssertEqual(counter.count, 1)
    }

    func testBackgroundTaskIsHeldUntilFlushCompletes() {
        let (analytics, destination) = makeAnalytics()
        let held = HeldFlush()
        analytics.add(plugin: held)
        let tasks = FakeBackgroundTasks()
        let ended = expectation(description: "background task ended")
        tasks.onEnd = { ended.fulfill() }

        destination.flushInBackground(using: tasks)

        XCTAssertEqual(tasks.begun, 1)
        XCTAssertEqual(held.entered.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(tasks.ended, [])

        held.release()
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(tasks.ended, [tasks.identifier])
    }

    func testBackgroundTaskEndsOnceWhenItExpires() {
        let (analytics, destination) = makeAnalytics()
        let held = HeldFlush()
        analytics.add(plugin: held)
        let tasks = FakeBackgroundTasks()

        destination.flushInBackground(using: tasks)
        XCTAssertEqual(held.entered.wait(timeout: .now() + 5), .success)

        tasks.expirationHandler?()
        XCTAssertEqual(tasks.ended, [tasks.identifier])

        // let the original flush finish too; flushes are serial, so waiting on a later one waits on it.
        held.release()
        let flushed = expectation(description: "flush completed")
        analytics.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(tasks.ended, [tasks.identifier])
    }

    func testInvalidBackgroundTaskIsNotEnded() {
        let (analytics, destination) = makeAnalytics()
        let counter = FlushCounter()
        analytics.add(plugin: counter)
        let tasks = FakeBackgroundTasks()
        tasks.identifier = .invalid

        destination.flushInBackground(using: tasks)

        let flushed = expectation(description: "flush completed")
        analytics.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(tasks.ended, [])
    }

    func testWithoutBackgroundTasksStillFlushes() {
        let (analytics, destination) = makeAnalytics()
        let counter = FlushCounter()
        analytics.add(plugin: counter)

        destination.flushInBackground(using: nil)

        let flushed = expectation(description: "flush completed")
        analytics.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(counter.count, 2)
    }
}
#endif
