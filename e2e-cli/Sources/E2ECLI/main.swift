import Foundation
import Segment

// MARK: - Input/Output Models

struct CLIOutput: Codable {
    var success: Bool
    var error: String?
    var sentBatches: Int
}

struct CLIConfig: Codable {
    var flushAt: Int?
    var flushInterval: Double?
    var maxRetries: Int?
    var timeout: Int?
}

struct EventSequence: Codable {
    var delayMs: Int
    var events: [[String: AnyCodable]]
}

struct CLIInput: Codable {
    var writeKey: String
    var apiHost: String?
    var cdnHost: String?
    var sequences: [EventSequence]
    var config: CLIConfig?
}

// MARK: - AnyCodable helper for parsing dynamic JSON

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unable to encode value"))
        }
    }

    var stringValue: String? { value as? String }
    var dictValue: [String: Any]? { value as? [String: Any] }
}

// MARK: - Delivery error tracker (file-backed for cross-thread visibility)
//
// The Analytics errorHandler runs on a URLSession callback thread in synchronous
// operating mode. In-memory state (even with locks) is not reliably visible from
// the main thread. Using a temp file provides the necessary memory barrier.
//
// Two channels:
//   "transient" — last error from any flush cycle (cleared between retries)
//   "dropped"   — set when a batch is terminally dropped (never cleared)

class DeliveryErrorTracker {
    private let basePath: String
    let transientPath: String
    let droppedPath: String

    init() {
        basePath = NSTemporaryDirectory() + "e2ecli-errors-\(ProcessInfo.processInfo.processIdentifier)"
        transientPath = basePath + "-transient.log"
        droppedPath = basePath + "-dropped.log"
        clearTransient()
        try? "".write(toFile: droppedPath, atomically: false, encoding: .utf8)
    }

    /// Record a transient error (may be retried)
    func recordError(_ msg: String) {
        try? msg.write(toFile: transientPath, atomically: false, encoding: .utf8)
    }

    /// Record that a batch was permanently dropped
    func recordDrop(_ msg: String) {
        try? msg.write(toFile: droppedPath, atomically: false, encoding: .utf8)
    }

    /// Clear transient errors (between retry cycles)
    func clearTransient() {
        try? "".write(toFile: transientPath, atomically: false, encoding: .utf8)
    }

    /// True if any batch was dropped OR if the last flush had errors
    var hasErrors: Bool {
        return wasDropped || hasTransientErrors
    }

    var wasDropped: Bool {
        guard let content = try? String(contentsOfFile: droppedPath, encoding: .utf8) else { return false }
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasTransientErrors: Bool {
        guard let content = try? String(contentsOfFile: transientPath, encoding: .utf8) else { return false }
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var summary: String {
        if wasDropped {
            return (try? String(contentsOfFile: droppedPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return (try? String(contentsOfFile: transientPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    deinit {
        try? FileManager.default.removeItem(atPath: transientPath)
        try? FileManager.default.removeItem(atPath: droppedPath)
    }
}

// MARK: - Main

func parseArguments() -> String? {
    let args = CommandLine.arguments
    guard let inputIndex = args.firstIndex(of: "--input"),
          inputIndex + 1 < args.count else {
        return nil
    }
    return args[inputIndex + 1]
}

func sendEvent(analytics: Analytics, event: [String: AnyCodable]) throws {
    guard let type = event["type"]?.stringValue else {
        throw NSError(domain: "E2ECLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Event missing 'type' field"])
    }

    let userId = event["userId"]?.stringValue ?? ""
    let traits = event["traits"]?.dictValue ?? [:]
    let properties = event["properties"]?.dictValue ?? [:]
    let eventName = event["event"]?.stringValue
    let name = event["name"]?.stringValue
    let groupId = event["groupId"]?.stringValue

    switch type {
    case "identify":
        analytics.identify(userId: userId, traits: traits)
    case "track":
        analytics.track(name: eventName ?? "Unknown Event", properties: properties)
    case "page":
        analytics.screen(title: name ?? "Unknown Page", properties: properties)
    case "screen":
        analytics.screen(title: name ?? "Unknown Screen", properties: properties)
    case "alias":
        analytics.alias(newId: userId)
    case "group":
        analytics.group(groupId: groupId ?? "", traits: traits)
    default:
        throw NSError(domain: "E2ECLI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown event type: \(type)"])
    }
}

func main() {
    var output = CLIOutput(success: false, error: nil, sentBatches: 0)

    do {
        guard let inputJson = parseArguments() else {
            throw NSError(domain: "E2ECLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing required --input argument"])
        }

        guard let inputData = inputJson.data(using: .utf8) else {
            throw NSError(domain: "E2ECLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid input encoding"])
        }

        let decoder = JSONDecoder()
        let input = try decoder.decode(CLIInput.self, from: inputData)

        let maxRetries = input.config?.maxRetries ?? 100
        let tracker = DeliveryErrorTracker()

        var config = Configuration(writeKey: input.writeKey)
            .flushAt(input.config?.flushAt ?? 20)
            .flushInterval(input.config?.flushInterval ?? 30)
            .operatingMode(.synchronous)
            .storageMode(.memory(1000))
            .httpConfig(HttpConfig(
                rateLimitConfig: RateLimitConfig(enabled: true),
                backoffConfig: BackoffConfig(
                    enabled: true,
                    maxRetryCount: maxRetries,
                    baseBackoffInterval: 0.5
                )
            ))
            .errorHandler { error in
                let msg = "\(error)"
                var isDrop = false
                if let analyticsError = error as? AnalyticsError {
                    switch analyticsError {
                    case .batchUploadFail:
                        isDrop = true
                    case .networkServerRejected(_, let code):
                        // Non-retryable 4xx codes: 400-407, 411-427, 431+
                        // Retryable exceptions: 408, 410, 429, 460
                        let retryable4xx: Set<Int> = [408, 410, 429, 460]
                        if code >= 400 && code < 500 && !retryable4xx.contains(code) {
                            isDrop = true
                        }
                    default:
                        break
                    }
                }
                if isDrop {
                    tracker.recordDrop(msg)
                } else {
                    tracker.recordError(msg)
                }
            }

        if let apiHost = input.apiHost {
            config = config.apiHost(apiHost)
        }
        if let cdnHost = input.cdnHost {
            config = config.cdnHost(cdnHost)
        }

        let analytics = Analytics(configuration: config)

        // Wait for startup to complete (settings fetch, system becomes running)
        analytics.waitUntilStarted()

        // Process event sequences
        for seq in input.sequences {
            if seq.delayMs > 0 {
                Thread.sleep(forTimeInterval: Double(seq.delayMs) / 1000.0)
            }

            for event in seq.events {
                try sendEvent(analytics: analytics, event: event)
            }
        }

        // Flush and poll until delivery completes or times out.
        // In synchronous mode, flush() blocks until upload + callback complete,
        // so errorHandler fires inside flush(). With flushAt:1, auto-flushes
        // also happen during sendEvent above.
        let timeoutSec = input.config?.timeout ?? 30
        let deadline = Date().addingTimeInterval(Double(timeoutSec))

        // In synchronous mode with flushAt:1, auto-flushes happen during
        // sendEvent. Those may have already delivered (or dropped) events.
        // If events remain unsent, we enter the explicit flush/retry loop.
        //
        // Clear transient errors from auto-flushes. The "dropped" flag
        // persists — if any batch was dropped during auto-flush, we'll
        // detect it after the loop.
        tracker.clearTransient()

        if analytics.hasUnsentEvents {
            analytics.flush()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))

            while analytics.hasUnsentEvents && Date() < deadline {
                tracker.clearTransient()
                analytics.flush()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
            }
        }

        if analytics.hasUnsentEvents {
            output.error = "Delivery incomplete: events still pending"
        } else if tracker.hasErrors {
            output.error = "Delivery failed: \(tracker.summary)"
        } else {
            output.success = true
            output.sentBatches = 1
        }
    } catch {
        output.error = error.localizedDescription
    }

    let encoder = JSONEncoder()
    if let outputData = try? encoder.encode(output),
       let outputString = String(data: outputData, encoding: .utf8) {
        print(outputString)
    }

    exit(output.success ? 0 : 1)
}

main()
