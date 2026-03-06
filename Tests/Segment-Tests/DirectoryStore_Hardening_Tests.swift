//
//  DirectoryStore_Hardening_Tests.swift
//  Segment-Tests
//
//  Tests for crash-recovery hardening in DirectoryStore.
//
//  Scenario: app is killed after finishFile() writes the closing bracket
//  but before FileManager.moveItem renames the file to .temp. On next launch,
//  startFileIfNeeded() would reopen the same index file and append events after
//  the closing bracket, producing a structurally corrupt JSON batch.
//
//  The fix: isFinalized() checks if the file already has a sentAt footer.
//  If so, we skip past it by incrementing the index and starting fresh.
//

import XCTest
@testable import Segment

class DirectoryStore_Hardening_Tests: XCTestCase {

    var storageURL: URL!
    var store: DirectoryStore!

    override func setUpWithError() throws {
        Telemetry.shared.enable = false
        storageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("segment-hardening-tests")
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        store = DirectoryStore(configuration: DirectoryStore.Configuration(
            writeKey: "hardening-test",
            storageLocation: storageURL,
            baseFilename: "segment-events",
            maxFileSize: 475000,
            indexKey: "hardening.events"
        ))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storageURL)
        UserDefaults(suiteName: "com.segment.storage.hardening-test")?
            .removePersistentDomain(forName: "com.segment.storage.hardening-test")
    }

    // MARK: - Crash Recovery

    /// Simulates a crash after finishFile() wrote the closing bracket but before
    /// the rename to .temp succeeded. Without the fix, the next append would open
    /// the same file and write events after the closing bracket, corrupting the batch.
    func testCrashRecoverySkipsFinalizedFile() throws {
        // Pre-write a finalized file at index 0 — simulates the crash scenario.
        let finalizedFileURL = storageURL.appendingPathComponent("0-segment-events")
        let finalizedContent = "{ \"batch\": [\n{\"type\":\"track\",\"event\":\"CrashEvent\",\"messageId\":\"DEAD-BEEF\"}\n],\"sentAt\":\"2026-01-01T00:00:00.000Z\",\"writeKey\":\"hardening-test\"}"
        try finalizedContent.write(to: finalizedFileURL, atomically: true, encoding: .utf8)

        // Append a new event — should detect index 0 is finalized and use index 1.
        let event = TrackEvent(event: "PostCrashEvent", properties: nil)
        store.append(data: event)

        let result = store.fetch(count: nil, maxBytes: nil)

        XCTAssertNotNil(result, "Should have a result after appending past finalized file")
        XCTAssertFalse(result!.dataFiles!.isEmpty)

        // New events must land in index 1, not index 0.
        let uploadedFile = result!.dataFiles!.first!
        XCTAssertTrue(
            uploadedFile.lastPathComponent.hasPrefix("1-"),
            "Expected events in index 1 file, got: \(uploadedFile.lastPathComponent)"
        )

        // Verify the uploaded file contains only the post-crash event.
        let data = try Data(contentsOf: uploadedFile)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let batch = json["batch"] as! [[String: Any]]
        XCTAssertEqual(batch.count, 1)
        XCTAssertEqual(batch[0]["event"] as? String, "PostCrashEvent")

        // The original finalized file at index 0 should be left untouched.
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: finalizedFileURL.path),
            "Original finalized file should be untouched at index 0"
        )
    }

    /// Verifies that a non-finalized in-progress file (no sentAt footer) is NOT
    /// mistakenly skipped. App killed mid-write before finishFile() ran — we should
    /// resume appending to it, not abandon it.
    func testCrashRecoveryResumesUnfinishedFile() throws {
        // Write a partial file at index 0 — no sentAt footer means not finalized.
        let partialFileURL = storageURL.appendingPathComponent("0-segment-events")
        let partialContent = "{ \"batch\": [\n{\"type\":\"track\",\"event\":\"PartialEvent\",\"messageId\":\"PART-1\"}"
        try partialContent.write(to: partialFileURL, atomically: true, encoding: .utf8)

        // Append a new event — should resume into index 0, not skip to index 1.
        let event = TrackEvent(event: "ResumedEvent", properties: nil)
        store.append(data: event)

        let result = store.fetch(count: nil, maxBytes: nil)

        XCTAssertNotNil(result)
        let uploadedFile = result!.dataFiles!.first!

        XCTAssertTrue(
            uploadedFile.lastPathComponent.hasPrefix("0-"),
            "Expected resumed file at index 0, got: \(uploadedFile.lastPathComponent)"
        )
    }
}
