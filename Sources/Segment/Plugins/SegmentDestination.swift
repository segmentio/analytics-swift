//
//  SegmentDestination.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation
import Sovran

#if os(Linux)
// Whoever is doing swift/linux development over there
// decided that it'd be a good idea to split out a TON
// of stuff into another framework that NO OTHER PLATFORM
// has; I guess to be special.  :man-shrugging:
import FoundationNetworking
#endif

public class SegmentAnonymousId: AnonymousIdGenerator {
    public func newAnonymousId() -> String {
        return UUID().uuidString
    }
}

open class SegmentDestination: DestinationPlugin, Subscriber, FlushCompletion {
    public init() { }
    
    internal enum Constants: String {
        case integrationName = "Customer.io Data Pipelines"
        case apiHost = "apiHost"
        case apiKey = "apiKey"
    }
    
    public let type = PluginType.destination
    public let key: String = Constants.integrationName.rawValue
    public let timeline = Timeline()
    public weak var analytics: Analytics? {
        didSet {
            initialSetup()
        }
    }

    internal struct UploadTaskInfo {
        let url: URL?
        let data: Data?
        let task: URLSessionDataTask
        // set/used via an extension in iOSLifecycleMonitor.swift
        typealias CleanupClosure = () -> Void
        var cleanup: CleanupClosure? = nil
    }
    
    internal var httpClient: HTTPClient?
    private var uploads = [UploadTaskInfo]()
    private let uploadsQueue = DispatchQueue(label: "uploadsQueue.segment.com")
    private var storage: Storage?
    
    @Atomic internal var eventCount: Int = 0
    
    internal func initialSetup() {
        guard let analytics = self.analytics else { return }
        storage = analytics.storage
        httpClient = HTTPClient(analytics: analytics)
        
        // Add DestinationMetadata enrichment plugin
        add(plugin: DestinationMetadataPlugin())
    }
    
    public func update(settings: Settings, type: UpdateType) {
        guard let analytics = analytics else { return }
        let segmentInfo = settings.integrationSettings(forKey: self.key)
        // if customer cycles out a writekey at app.segment.com, this is necessary.
        /*
         This actually works differently than anticipated.  It was thought that when a writeKey was
         revoked, it's old writekey would redirect to the new, but it doesn't work this way.  As a result
         it doesn't appear writekey can be changed remotely.  Leaving this here in case that changes in the
         near future (written on 10/29/2022).
         */
        /*
        if let key = segmentInfo?[Self.Constants.apiKey.rawValue] as? String, key.isEmpty == false {
            if key != analytics.configuration.values.writeKey {
                /*
                 - would need to flush.
                 - would need to change the writeKey across the system.
                 - would need to re-init storage.
                 - probably other things too ...
                 */
            }
        }
         */
        // if customer specifies a different apiHost (ie: eu1.segmentapis.com) at app.segment.com ...
        if let host = segmentInfo?[Self.Constants.apiHost.rawValue] as? String, host.isEmpty == false {
            if host != analytics.configuration.values.apiHost {
                analytics.configuration.values.apiHost = host
                httpClient = HTTPClient(analytics: analytics)
            }
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
    internal func enterForeground() { }
    
    internal func enterBackground() {
        flush()
    }
    
    // MARK: - Event Parsing Methods
    private func queueEvent<T: RawEvent>(event: T) {
        guard let storage = self.storage else { return }
        // Send Event to File System
        storage.write(.events, value: event)
        self._eventCount.withValue { count in
            count += 1
        }
    }
    
    public func flush() {
        // unused .. see flush(group:completion:)
    }
    
    public func flush(group: DispatchGroup) {
        group.enter()
        defer { group.leave() }
        
        guard let storage = self.storage else { return }
        guard let analytics = self.analytics else { return }
        
        // don't flush if analytics is disabled.
        guard analytics.enabled == true else { return }
        
        eventCount = 0
        cleanupUploads()
        
        let type = storage.dataStore.transactionType
        let hasData = storage.dataStore.hasData
        
        analytics.log(message: "Uploads in-progress: \(pendingUploads)")
        
        if pendingUploads == 0 {
            if type == .file, hasData {
                flushFiles(group: group)
            } else if type == .data, hasData {
                // we know it's a data-based transaction as opposed to file I/O
                flushData(group: group)
            }
        } else {
            analytics.log(message: "Skipping processing; Uploads in progress.")
        }
    }
}

extension SegmentDestination {
    private func flushFiles(group: DispatchGroup) {
        guard let storage = self.storage else { return }
        guard let analytics = self.analytics else { return }
        guard let httpClient = self.httpClient else { return }

        // Cooperative release of allocated memory by URL instances (dataFiles).
        autoreleasepool {
            guard let files = storage.dataStore.fetch()?.dataFiles else { return }
            
            for url in files {
                // Use the autorelease pool to ensure that unnecessary memory allocations
                // are released after each iteration. If there is a large backlog of files
                // to iterate, the host applications may crash due to OOM issues.
                autoreleasepool {
                    // enter for this url we're going to kick off
                    group.enter()
                    analytics.log(message: "Processing Batch:\n\(url.lastPathComponent)")
                    
                    // set up the task
                    let uploadTask = httpClient.startBatchUpload(writeKey: analytics.configuration.values.writeKey, batch: url) { [weak self] result in
                        defer {
                            group.leave()
                        }
                        guard let self else { return }
                        switch result {
                        case .success(_):
                            storage.remove(data: [url])
                            cleanupUploads()
                            
                            // we don't want to retry events in a given batch when a 400
                            // response for malformed JSON is returned
                        case .failure(CioAnalytics.HTTPClientErrors.statusCode(code: 400)):
                            storage.remove(data: [url])
                            cleanupUploads()
                        default:
                            break
                        }
                        
                        analytics.log(message: "Processed: \(url.lastPathComponent)")
                        // the upload we have here has just finished.
                        // make sure it gets removed and it's cleanup() called rather
                        // than waiting on the next flush to come around.
                        cleanupUploads()
                    }
                    
                    // we have a legit upload in progress now, so add it to our list.
                    if let upload = uploadTask {
                        add(uploadTask: UploadTaskInfo(url: url, data: nil, task: upload))
                    } else {
                        // we couldn't get a task, so we need to leave the group or things will hang.
                        group.leave()
                    }
                }
            }
        }
    }
    
    private func flushData(group: DispatchGroup) {
        // DO NOT CALL THIS FROM THE MAIN THREAD, IT BLOCKS!
        // Don't make me add a check here; i'll be sad you didn't follow directions.
        guard let storage = self.storage else { return }
        guard let analytics = self.analytics else { return }
        guard let httpClient = self.httpClient else { return }
        
        let totalCount = storage.dataStore.count
        var currentCount = 0
        
        guard totalCount > 0 else { return }
        
        while currentCount < totalCount {
            // can't imagine why we wouldn't get data at this point, but if we don't, then split.
            guard let eventData = storage.dataStore.fetch() else { return }
            guard let data = eventData.data else { return }
            guard let removable = eventData.removable else { return }
            guard let dataCount = eventData.removable?.count else { return }
            
            currentCount += dataCount
            
            // enter for this data we're going to kick off
            group.enter()
            analytics.log(message: "Processing In-Memory Batch (size: \(data.count))")
            
            // we're already on a separate thread.
            // lets let this task complete so we can get all the values out.
            let semaphore = DispatchSemaphore(value: 0)
            
            // set up the task
            let uploadTask = httpClient.startBatchUpload(writeKey: analytics.configuration.values.writeKey, data: data) { [weak self] result in
                defer {
                    // leave for the url we kicked off.
                    group.leave()
                    semaphore.signal()
                }
                
                guard let self else { return }
                switch result {
                case .success(_):
                    storage.remove(data: removable)
                    cleanupUploads()
                    
                    // we don't want to retry events in a given batch when a 400
                    // response for malformed JSON is returned
                case .failure(CioAnalytics.HTTPClientErrors.statusCode(code: 400)):
                    storage.remove(data: removable)
                    cleanupUploads()
                default:
                    break
                }
                
                analytics.log(message: "Processed In-Memory Batch (size: \(data.count))")
                // the upload we have here has just finished.
                // make sure it gets removed and it's cleanup() called rather
                // than waiting on the next flush to come around.
                cleanupUploads()
            }
            
            // we have a legit upload in progress now, so add it to our list.
            if let upload = uploadTask {
                add(uploadTask: UploadTaskInfo(url: nil, data: data, task: upload))
            } else {
                // we couldn't get a task, so we need to leave the group or things will hang.
                group.leave()
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .distantFuture)
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
