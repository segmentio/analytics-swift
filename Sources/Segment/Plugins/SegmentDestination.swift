//
//  SegmentDestination.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

public class SegmentDestination: DestinationPlugin {
    public let type: PluginType = .destination
    public let name: String
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
        var taskID: Int = 0
        var cleanup: CleanupClosure? = nil
    }
    
    private var httpClient: HTTPClient?
    private var uploads = [UploadTaskInfo]()
    private var storage: Storage?
    private var maxPayloadSize = 500000 // Max 500kb
    
    private var apiKey: String? = nil
    private var apiHost: String? = nil
    
    @Atomic private var eventCount: Int = 0
    internal var flushTimer: QueueTimer? = nil
    
    internal enum Constants: String {
        case integrationName = "Segment.io"
        case apiHost = "apiHost"
        case apiKey = "apiKey"
    }
    
    required public init(name: String) {
        self.name = name
    }
    
    internal func initialSetup() {
        guard let analytics = self.analytics else { return }
        storage = analytics.storage
        httpClient = HTTPClient(analytics: analytics)
        flushTimer = QueueTimer(interval: analytics.configuration.values.flushInterval) {
            self.flush()
        }
    }
    
    public func update(settings: Settings) {
        let segmentInfo = settings.integrationSettings(for: Self.Constants.integrationName.rawValue)
        apiKey = segmentInfo?[Self.Constants.apiKey.rawValue] as? String
        apiHost = segmentInfo?[Self.Constants.apiHost.rawValue] as? String
        if (apiHost != nil && apiKey != nil), let analytics = self.analytics {
            httpClient = HTTPClient(analytics: analytics, apiKey: apiKey, apiHost: apiHost)
        }
    }
    
    // MARK: - Event Handling Methods
    public func identify(event: IdentifyEvent) -> IdentifyEvent? {
        queueEvent(event: event)
        return event
    }
    
    public func track(event: TrackEvent) -> TrackEvent? {
        queueEvent(event: event)
        return event
    }
    
    public func screen(event: ScreenEvent) -> ScreenEvent? {
        queueEvent(event: event)
        return event
    }
    
    public func alias(event: AliasEvent) -> AliasEvent? {
        queueEvent(event: event)
        return event
    }
    
    public func group(event: GroupEvent) -> GroupEvent? {
        queueEvent(event: event)
        return event
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
                
                if isPayloadSizeAcceptable(url: url) {
                    let uploadTask = httpClient.startBatchUpload(writeKey: analytics.configuration.values.writeKey, batch: url) { (result) in
                        switch result {
                        case .success(_):
                            storage.remove(file: url)
                        default:
                            analytics.logFlush()
                        }

                        analytics.log(message: "Processed: \(url.lastPathComponent)")
                    }
                    // we have a legit upload in progress now, so add it to our list.
                    if let upload = uploadTask {
                        add(uploadTask: UploadTaskInfo(url: url, task: upload))
                    }
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
    
    internal var pendingUploads: Int {
        return uploads.count
    }
    
    internal func add(uploadTask: UploadTaskInfo) {
        uploads.append(uploadTask)
    }
    
    internal func isPayloadSizeAcceptable(url: URL) -> Bool {
        var result = true
        var fileSizeTotal: Int64 = 0
        
        // Make sure we're under the max payload size.
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[FileAttributeKey.size] as? Int64 else {
                analytics?.log(message: "File size could not be read")
                // none of the logic beyond here will work if we can't get the
                // filesize so assume everything is good and hope for the best.
                return true
            }
            fileSizeTotal += fileSize
        } catch {
            analytics?.log(message: "Could not read file attributes")
        }
        
        if fileSizeTotal >= maxPayloadSize {
            analytics?.log(message: "Batch file is too large to be sent")
            result = false
        }
        return result
    }
    
}
