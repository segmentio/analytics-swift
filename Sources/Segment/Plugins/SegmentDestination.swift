//
//  SegmentDestination.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

#if os(Linux)
// Whoever is doing swift/linux development over there
// decided that it'd be a good idea to split out a TON
// of stuff into another framework that NO OTHER PLATFORM
// has; I guess to be special.  :man-shrugging:
import FoundationNetworking
#endif

public class SegmentDestination: DestinationPlugin {
    internal enum Constants: String {
        case integrationName = "Segment.io"
        case apiHost = "apiHost"
        case apiKey = "apiKey"
    }
    
    public let type = PluginType.destination
    public let key: String = Constants.integrationName.rawValue
    public let timeline = Timeline()
    public var analytics: Analytics? {
        didSet {
            initialSetup()
        }
    }

    internal struct UploadTaskInfo {
        let url: URL
        let task: URLSessionDataTask
        // set/used via an extension in iOSLifecycleMonitor.swift
        typealias CleanupClosure = () -> Void
        var cleanup: CleanupClosure? = nil
    }
    
    private var httpClient: HTTPClient?
    private var uploads = [UploadTaskInfo]()
    private let uploadsQueue = DispatchQueue(label: "uploadsQueue.segment.com")
    private var storage: Storage?
    
    private var apiKey: String? = nil
    private var apiHost: String? = nil
    
    @Atomic private var eventCount: Int = 0
    internal var flushTimer: QueueTimer? = nil
    
    internal func initialSetup() {
        guard let analytics = self.analytics else { return }
        storage = analytics.storage
        httpClient = HTTPClient(analytics: analytics)
        flushTimer = QueueTimer(interval: analytics.configuration.values.flushInterval) {
            self.flush()
        }
        // Add DestinationMetadata enrichment plugin
        add(plugin: DestinationMetadataPlugin())
    }
    
    public func update(settings: Settings, type: UpdateType) {
        let segmentInfo = settings.integrationSettings(forKey: self.key)
        apiKey = segmentInfo?[Self.Constants.apiKey.rawValue] as? String
        apiHost = segmentInfo?[Self.Constants.apiHost.rawValue] as? String
        if (apiHost != nil && apiKey != nil), let analytics = self.analytics {
            httpClient = HTTPClient(analytics: analytics, apiKey: apiKey, apiHost: apiHost)
        }
    }
    
    // MARK: - Event Handling Methods
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard let event = event else { return nil }
        let result = process(incomingEvent: event)
        if let r = result {
            queueEvent(event: r)
        }
        return result
    }
    
    // MARK: - Abstracted Lifecycle Methods
    internal func enterForeground() {
        flushTimer?.resume()
    }
    
    internal func enterBackground() {
        flushTimer?.suspend()
        flush()
    }
    
    // MARK: - Event Parsing Methods
    private func queueEvent<T: RawEvent>(event: T) {
        guard let storage = self.storage else { return }
        guard let analytics = self.analytics else { return }
        
        // Send Event to File System
        storage.write(.events, value: event)
        eventCount += 1
        if eventCount >= analytics.configuration.values.flushAt {
            eventCount = 0
            flush()
        }
    }
    
    public func flush() {
        guard let storage = self.storage else { return }
        guard let analytics = self.analytics else { return }
        guard let httpClient = self.httpClient else { return }

        // Read events from file system
        guard let data = storage.read(Storage.Constants.events) else { return }
        
        cleanupUploads()
        
        analytics.log(message: "Uploads in-progress: \(pendingUploads)")
        
        if pendingUploads == 0 {
            for url in data {
                analytics.log(message: "Processing Batch:\n\(url.lastPathComponent)")
                
                let uploadTask = httpClient.startBatchUpload(writeKey: analytics.configuration.values.writeKey, batch: url) { (result) in
                    switch result {
                        case .success(_):
                            storage.remove(file: url)
                        default:
                            analytics.logFlush()
                    }
                    
                    analytics.log(message: "Processed: \(url.lastPathComponent)")
                    // the upload we have here has just finished.
                    // make sure it gets removed and it's cleanup() called rather
                    // than waiting on the next flush to come around.
                    self.cleanupUploads()
                }
                // we have a legit upload in progress now, so add it to our list.
                if let upload = uploadTask {
                    add(uploadTask: UploadTaskInfo(url: url, task: upload))
                }
            }
        } else {
            analytics.log(message: "Skipping processing; Uploads in progress.")
        }
    }
}

// MARK: - Upload management

extension SegmentDestination {
    internal func cleanupUploads() {
        // lets go through and get rid of any tasks that aren't running.
        // either they were suspended because a background task took too
        // long, or the os orphaned it due to device constraints (like a watch).
        uploadsQueue.sync {
            let before = uploads.count
            var newPending = uploads
            newPending.removeAll { uploadInfo in
                let shouldRemove = uploadInfo.task.state != .running
                if shouldRemove, let cleanup = uploadInfo.cleanup {
                    cleanup()
                }
                return shouldRemove
            }
            uploads = newPending
            let after = uploads.count
            analytics?.log(message: "Cleaned up \(before - after) non-running uploads.")
        }
    }
    
    internal var pendingUploads: Int {
        var uploadsCount = 0
        uploadsQueue.sync {
            uploadsCount = uploads.count
        }
        return uploadsCount
    }
    
    internal func add(uploadTask: UploadTaskInfo) {
        uploadsQueue.sync {
            uploads.append(uploadTask)
        }
    }
}

// MARK: Versioning

extension SegmentDestination: VersionedPlugin {
    public static func version() -> String {
        return __segment_version
    }
}
