# Batch Corruption Workaround (v1.9.1 and earlier)

## Issue

In analytics-swift versions prior to v1.9.2, a race condition could cause batch payload corruption when multiple events are queued for async appending during a flush operation. This results in malformed JSON where events are appended outside the batch array, causing silent data loss.

**Symptoms:**
- Batch array closes prematurely after first event
- Subsequent events appended as raw JSON after closing bracket
- Server returns 200 OK but only processes first event
- No error reported to application

## Workaround

If you are using analytics-swift v1.9.1 or earlier and experiencing batch corruption, use **synchronous operating mode** to eliminate the race condition:

```swift
// Change from:
let analytics = Analytics(configuration: Configuration(writeKey: "YOUR_WRITE_KEY"))

// To:
let analytics = Analytics(configuration: Configuration(writeKey: "YOUR_WRITE_KEY")
    .operatingMode(.synchronous))
```

## What This Does

Synchronous mode forces all event appending to happen synchronously on the storage queue, preventing the race condition where `finishFile()` can execute between queued async appends.

## Trade-offs

- **Slight performance impact**: Event tracking will block the calling thread briefly while writing to storage
- **Still production-safe**: The blocking is minimal (microseconds for file append)
- **Better than data loss**: Guaranteed data integrity vs. silent event loss

## Upgrade Path

**Recommended:** Upgrade to analytics-swift v1.9.2 or later, which fixes the race condition while maintaining async performance.

```swift
// In Package.swift
dependencies: [
    .package(url: "https://github.com/segmentio/analytics-swift", from: "1.9.2")
]
```

Once upgraded, you can remove `.operatingMode(.synchronous)` to return to async mode with the race condition fix applied.

## Additional Information

For technical details about the race condition and fix, see:
- [Issue Discussion](link to issue)
- [Pull Request](link to PR)
- Technical analysis in `/Users/digarcia/research/analytics-swift-batch-corruption-bug.md`
