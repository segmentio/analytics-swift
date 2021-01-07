//
//  SegmentDestination.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

class SegmentDestination: DestinationExtension {
    
    var analytics: Analytics
    var extensions: Extensions
    var type: ExtensionType
    var name: String
    private var httpClient: HTTPClient
    private var pendingURLs = [URL]()
    private var uploadInProgress = false
    private var storage: Storage
    
    required init(name: String, analytics: Analytics) {
        type = .destination
        self.name = name
        self.analytics = analytics
        extensions = Extensions()
        storage = analytics.storage
        httpClient = HTTPClient(analytics: analytics)
    }
    
    // MARK: - Event Handling Methods
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        queueEvent(event: event)
        return event
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        queueEvent(event: event)
        return event
    }
    
    // MARK: - Event Parsing Methods
    private func queueEvent<T: RawEvent>(event: T) {
        // Send Event to File System
        storage.write(.events, value: event)
                
        // flush the queue
        flush()
    }
    
    private func flush() {
        // Read events from file system
        guard let data = storage.read(Storage.Constants.events) else { return }
        
        if !uploadInProgress {
            uploadInProgress = true
            var processedCall = [Bool]()
            for url in data {
                
                httpClient.startBatchUpload(writeKey: analytics.configuration.writeKey, batch: url, completion: { [weak self] (succeeded) in

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
                    
                    // TODO: Mark as completed via notification???????
                    
                })
            }
        }
    }
}

extension Analytics {
    func flushB() {
        // TODO: Cycle extensions to respond
    }
}
