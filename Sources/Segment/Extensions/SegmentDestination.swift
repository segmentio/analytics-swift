//
//  SegmentDestination.swift
//  Segment
//
//  Created by Cody Garvin on 1/5/21.
//

import Foundation

class SegmentDestination: DestinationExtension {
    var extensions: Extensions
    
    var type: ExtensionType
    var name: String
    weak var _analytics: Analytics? = nil
    private var httpClient: HTTPClient?
    private var events = [RawEvent]()
    
    required init(name: String) {
        type = .destination
        self.name = name
        extensions = Extensions()
    }
    
    convenience init(name: String, analytics: Analytics) {
        self.init(name: name)
        _analytics = analytics
        httpClient = HTTPClient(analytics: analytics)
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        queueEvent(event: event)
        return event
    }
    
    // MARK: - Event Parsing Methods
    private func queueEvent(event: RawEvent) {
        // TODO: trim by one of max payload to make room
        events.append(event)
        
        // Save queue to disk
        
        // flush the queue
        flush()
    }
    
    private func flush() {
        // Build a set of JSON events to send off
        var jsonQueue = [JSON]()
        var eventsCopy: [RawEvent]? = events
        for item in events {
            if let jsonEncoded = try? JSON(item) {
                jsonQueue.append(jsonEncoded)
            }
        }
        
        if !jsonQueue.isEmpty, let writeKey = analytics?.configuration.writeKey {
            httpClient?.startBatchUpload(writeKey: writeKey, batch: jsonQueue, completion: { (shouldRetry) in
                if shouldRetry {
                    eventsCopy = nil
                    return
                }
                
                // Remove events
                guard var eventsCopy = eventsCopy else { return }
                eventsCopy.removeSubrange(0..<jsonQueue.count-1)
                
                // Store what's left
                
                // Mark as completed?
            
            })
        }
    }
}
