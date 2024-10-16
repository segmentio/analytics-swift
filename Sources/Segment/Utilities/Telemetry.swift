import Foundation
import Sovran

public struct RemoteMetric: Codable {
    let type: String
    let metric: String
    var value: Int
    let tags: [String: String]
    let log: [String: String]?

    init(type: String, metric: String, value: Int, tags: [String: String], log: [String: String]? = nil) {
        self.type = type
        self.metric = metric
        self.value = value
        self.tags = tags
        self.log = log
    }
}

private let METRIC_TYPE = "Counter"

func logError(_ error: Error) {
    Analytics.reportInternalError(error)
}

public class Telemetry: Subscriber {
    public static let shared = Telemetry(session: URLSession.shared)
    private static let METRICS_BASE_TAG = "analytics_mobile"
    public static let INVOKE_METRIC = "\(METRICS_BASE_TAG).invoke"
    public static let INVOKE_ERROR_METRIC = "\(METRICS_BASE_TAG).invoke.error"
    public static let INTEGRATION_METRIC = "\(METRICS_BASE_TAG).integration.invoke"
    public static let INTEGRATION_ERROR_METRIC = "\(METRICS_BASE_TAG).integration.invoke.error"

    init(session: any HTTPSession) {
        self.session = session
    }

    public var enable: Bool = false {
        didSet {
            if enable {
                start()
            }
        }
    }
    internal var session: any HTTPSession
    public var host: String = HTTPClient.getDefaultAPIHost()
    var sampleRate: Double = 0.10
    public var flushTimer: Int = 30 * 1000
    public var sendWriteKeyOnError: Bool = true
    public var sendErrorLogData: Bool = false
    public var errorHandler: ((Error) -> Void)? = logError
    public var maxQueueSize: Int = 20
    var errorLogSizeMax: Int = 4000

    static private let MAX_QUEUE_BYTES = 28000
    var maxQueueBytes: Int = MAX_QUEUE_BYTES {
        didSet {
            maxQueueBytes = min(maxQueueBytes, Telemetry.MAX_QUEUE_BYTES)
        }
    }

    public var queue = [RemoteMetric]()
    private var queueBytes = 0
    private var queueSizeExceeded = false
    private var seenErrors = [String: Int]()
    public var started = false
    private var rateLimitEndTime: TimeInterval = 0
    private var telemetryQueue = DispatchQueue(label: "telemetryQueue")
    private var telemetryTimer: Timer?

    func start() {
        guard enable, !started, sampleRate > 0.0 && sampleRate <= 1.0 else { return }
        started = true

        if Double.random(in: 0...1) > sampleRate {
            resetQueue()
        }

        telemetryTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(flushTimer) / 1000.0, repeats: true) { [weak self] _ in
            if (!(self?.enable ?? false)) {
                self?.started = false
                self?.telemetryTimer?.invalidate()
            }
            self?.flush()
        }
    }

    func reset() {
        telemetryTimer?.invalidate()
        resetQueue()
        seenErrors.removeAll()
        started = false
        rateLimitEndTime = 0
    }

    func increment(metric: String, buildTags: (inout [String: String]) -> Void) {
        var tags = [String: String]()
        buildTags(&tags)

        guard enable, sampleRate > 0.0 && sampleRate <= 1.0, metric.hasPrefix(Telemetry.METRICS_BASE_TAG), !tags.isEmpty, queueHasSpace() else { return }
        if Double.random(in: 0...1) > sampleRate { return }

        addRemoteMetric(metric: metric, tags: tags)
    }

    func error(metric: String, log: String, buildTags: (inout [String: String]) -> Void) {
        var tags = [String: String]()
        buildTags(&tags)

        guard enable, sampleRate > 0.0 && sampleRate <= 1.0, metric.hasPrefix(Telemetry.METRICS_BASE_TAG), !tags.isEmpty, queueHasSpace() else { return }

        var filteredTags = tags
        if !sendWriteKeyOnError {
            filteredTags = tags.filter { $0.key.lowercased() != "writekey" }
        }

        var logData: String? = nil
        if sendErrorLogData {
            logData = String(log.prefix(errorLogSizeMax))
        }

        if let errorKey = tags["error"] {
            if let count = seenErrors[errorKey] {
                seenErrors[errorKey] = count + 1
                if Double.random(in: 0...1) > sampleRate { return }
                addRemoteMetric(metric: metric, tags: filteredTags, value: Int(Double(count) * sampleRate), log: logData)
                seenErrors[errorKey] = 0
            } else {
                addRemoteMetric(metric: metric, tags: filteredTags, log: logData)
                flush()
                seenErrors[errorKey] = 0
            }
        } else {
            addRemoteMetric(metric: metric, tags: filteredTags, log: logData)
        }
    }

    @objc func flush() {
        guard enable else { return }

        telemetryQueue.sync {
            guard !queue.isEmpty else { return }
            if rateLimitEndTime > Date().timeIntervalSince1970 {
                return
            }
            rateLimitEndTime = 0

            do {
                try send()
                queueBytes = 0
            } catch {
                errorHandler?(error)
                sampleRate = 0.0
            }
        }
    }

private func send() throws {
        guard sampleRate > 0.0 && sampleRate <= 1.0 else { return }

        var sendQueue = [RemoteMetric]()
        while !queue.isEmpty {
            var metric = queue.removeFirst()
            metric.value = Int(Double(metric.value) / sampleRate)
            sendQueue.append(metric)
        }
        queueBytes = 0
        queueSizeExceeded = false

        let payload = try JSONEncoder().encode(["series": sendQueue])
        var request = upload(apiHost: host)
        request.httpBody = payload

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                self.errorHandler?(error)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                if let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? String, let retryAfterSeconds = TimeInterval(retryAfter) {
                    self.rateLimitEndTime = retryAfterSeconds + Date().timeIntervalSince1970
                }
            }
        }
        task.resume()
    }

    private var additionalTags: [String: String] {
        var osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let osRegex = try! NSRegularExpression(pattern: "[0-9]+", options: [])
        if let match = osRegex.firstMatch(in: osVersion, options: [], range: NSRange(location: 0, length: osVersion.utf16.count)) {
            osVersion = (osVersion as NSString).substring(with: match.range)
        }
        #if os(iOS)
        osVersion = "iOS-\(osVersion)"
        #elseif os(macOS)
        osVersion = "macOS-\(osVersion)"
        #elseif os(tvOS)
        osVersion = "tvOS-\(osVersion)"
        #elseif os(watchOS)
        osVersion = "watchOS-\(osVersion)"
        #else
        osVersion = "unknown-\(osVersion)"
        #endif

        return [
            "os": "\(osVersion)",
            "library": "analytics.swift",
            "library_version": __segment_version
        ]
    }

private func addRemoteMetric(metric: String, tags: [String: String], value: Int = 1, log: String? = nil) {
        let fullTags = tags.merging(additionalTags) { (_, new) in new }

        telemetryQueue.sync {
            if var found = queue.first(where: { $0.metric == metric && $0.tags == fullTags }) {
                found.value += value
                return
            }

            let newMetric = RemoteMetric(
                type: METRIC_TYPE,
                metric: metric,
                value: value,
                tags: fullTags,
                log: log != nil ? ["timestamp": Date().iso8601() , "trace": log!] : nil
            )
            let newMetricSize = String(describing: newMetric).data(using: .utf8)?.count ?? 0
            if queueBytes + newMetricSize <= maxQueueBytes {
                queue.append(newMetric)
                queueBytes += newMetricSize
            } else {
                queueSizeExceeded = true
            }
        }
    }

    func subscribe(_ store: Store) {
        store.subscribe(self,
            initialState: true,
            queue: telemetryQueue,
            handler: systemUpdate
        )
    }

    private func systemUpdate(system: System) {
        if let settings = system.settings, let sampleRate = settings.metrics?["sampleRate"]?.doubleValue {
            self.sampleRate = sampleRate
            start()
        }
    }

    private func upload(apiHost: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://\(apiHost)/m")!)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"

        return request
    }

    private func queueHasSpace() -> Bool {
        var under = false
        telemetryQueue.sync {
            under = queue.count < maxQueueSize
        }
        return under
    }

    private func resetQueue() {
        telemetryQueue.sync {
            queue.removeAll()
            queueBytes = 0
            queueSizeExceeded = false
        }
    }
}
