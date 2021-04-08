//
//  SegmentDestination.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

public class SegmentDestination: DestinationPlugin {
    public var analytics: Analytics
    public var timeline: Timeline
    public var type: PluginType
    public var name: String
    
    private var httpClient: HTTPClient
    private var pendingURLs = [URL]()
    private var uploadInProgress = false
    private var storage: Storage
    private var maxPayloadSize = 500000 // Max 500kb
    
    private var eventCount: Int = 0
    private var flushTimer: Timer? = nil
    
    internal enum Constants: String {
        case integrationName = "Segment.io"
        case apiHost = "apiHost"
        case apiKey = "apiKey"
    }
    
    required public init(name: String, analytics: Analytics) {
        type = .destination
        self.name = name
        self.analytics = analytics
        timeline = Timeline()
        storage = analytics.storage
        httpClient = HTTPClient(analytics: analytics)
        flushTimer = Timer.scheduledTimer(withTimeInterval: analytics.configuration.values.flushInterval, repeats: true, block: { _ in
            self.flush()
        })
    }
    
    public func update(settings: Settings) {
        let segmentInfo = settings.integrationSettings(for: "Segment.io")
        let apiKey = segmentInfo?[Self.Constants.apiKey.rawValue] as? String
        let apiHost = segmentInfo?[Self.Constants.apiHost.rawValue] as? String
        if (apiHost != nil && apiKey != nil) {
            httpClient = HTTPClient(analytics: self.analytics, apiKey: apiKey, apiHost: apiHost)
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
    
    // MARK: - Event Parsing Methods
    private func queueEvent<T: RawEvent>(event: T) {
        // Send Event to File System
        storage.write(.events, value: event)
        if eventCount >= analytics.configuration.values.flushAt {
            flush()
        }
    }
    
    internal func flush() {
        if Thread.isMainThread == false {
            DispatchQueue.main.async {
                self.flush()
            }
            return
        }
        
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
                        self?.storage.remove(file: url)
                    } else {
                        self?.analytics.logFlush()
                    }

                    if processedCall.count == data.count {
                        self?.uploadInProgress = false
                    }
                })
            }
        }
    }
}

extension Analytics {
    internal func flushCurrentPayload() {
        apply { (plugin) in
            if let destinationPlugin = plugin as? SegmentDestination {
                destinationPlugin.flush()
            }
        }
    }
}
