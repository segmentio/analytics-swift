//
//  SegmentDestination.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

public class SegmentDestination: QueueingCore, DestinationPlugin {
    public let type: PluginType = .destination
    public let name: String
    public let timeline = Timeline()
    public override var analytics: Analytics? {
        didSet {
            initialSetup()
        }
    }

    private var httpClient: HTTPClient?
    private var pendingURLs = [URL]()
    private var uploadInProgress = false
    private var storage: Storage?
    private var maxPayloadSize = 500000 // Max 500kb
    
    private var apiKey: String? = nil
    private var apiHost: String? = nil
    
    @Atomic private var eventCount: Int = 0
    private var flushTimer: Timer? = nil
    
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
        flushTimer = Timer.scheduledTimer(withTimeInterval: analytics.configuration.values.flushInterval, repeats: true, block: { _ in
            self.flush()
        })
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
    public override func identify(event: IdentifyEvent) -> IdentifyEvent? {
        queueEvent(event: event)
        return event
    }
    
    public override func track(event: TrackEvent) -> TrackEvent? {
        queueEvent(event: event)
        return event
    }
    
    public override func screen(event: ScreenEvent) -> ScreenEvent? {
        queueEvent(event: event)
        return event
    }
    
    public override func alias(event: AliasEvent) -> AliasEvent? {
        queueEvent(event: event)
        return event
    }
    
    public override func group(event: GroupEvent) -> GroupEvent? {
        queueEvent(event: event)
        return event
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
        
        if !uploadInProgress {
            uploadInProgress = true
            var processedCall = [Bool]()
            
            var fileSizeTotal: Int64 = 0
            for url in data {
                // Get the file size
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.absoluteString)
                    guard let fileSize = attributes[FileAttributeKey.size] as? Int64 else {
                        analytics.log(message: "File size could not be read")
                        return
                    }
                    fileSizeTotal += fileSize
                } catch {
                    analytics.log(message: "Could not read file attributes")
                }
                
                // Don't continue sending if the file size total has become too large
                // send it off in the next flush.
                if fileSizeTotal > maxPayloadSize {
                    analytics.log(message: "Batch file is too large to be sent")
                    break
                }
                
                httpClient.startBatchUpload(writeKey: analytics.configuration.values.writeKey, batch: url, completion: { [weak self] (succeeded) in
                    // Track that the call has finished
                    processedCall.append(succeeded)
                    
                    if succeeded {
                        // Remove events
                        storage.remove(file: url)
                    } else {
                        analytics.logFlush()
                    }

                    if processedCall.count == data.count {
                        self?.uploadInProgress = false
                    }
                })
            }
        }
    }
}
