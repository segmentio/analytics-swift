//
//  Metrics.swift
//  Segment
//
//  Created by Cody Garvin on 12/15/20.
//

import Foundation

public enum MetricType: Int {
    case counter = 0    // Not Verbose
    case gauge          // Semi-verbose
    
    func toString() -> String {
        if self == .counter {
            return "Counter"
        } else {
            return "Gauge"
        }
    }
    
    static func fromString(_ string: String) -> Self {
        if string == "Gauge" {
            return .gauge
        } else {
            return .counter
        }
    }
}


public extension RawEvent {
    mutating func addMetric(_ type: MetricType, name: String, value: Double, tags: [String]?, timestamp: Date) {
        guard let metric = try? JSON(with: Metric(eventName: "\(Self.self)", metricName: name, value: value, tags: tags, type: type, timestamp: Date())) else { return }
        if self.metrics == nil {
            metrics = [JSON]()
        }
        
        if let jsonEncoded = try? JSON(with: metric) {
            metrics?.append(jsonEncoded)
        }
    }
}

fileprivate struct Metric: Codable {
    var eventName: String = ""
    var metricName: String = ""
    var value: Double = 0.0
    var tags: [String]? = nil
    var type: MetricType = .counter
    var timestamp: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case eventName
        case metricName
        case value
        case tags
        case type
        case timestamp
    }
    
    init(eventName: String, metricName: String, value: Double, tags: [String]?, type: MetricType, timestamp: Date) {
        self.eventName = eventName
        self.metricName = metricName
        self.value = value
        self.tags = tags
        self.type = type
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        eventName = try values.decode(String.self, forKey: .eventName)
        metricName = try values.decode(String.self, forKey: .metricName)
        value = try values.decode(Double.self, forKey: .value)
        tags = try values.decode([String]?.self, forKey: .tags)
        
        let timestampString = try values.decode(String.self, forKey: .timestamp)
        if let timestampDate = timestampString.iso8601() {
            timestamp = timestampDate
        }
        
        let typeString = try values.decode(String.self, forKey: .type)
        type = MetricType.fromString(typeString)
    }
    
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(eventName, forKey: .eventName)
        try values.encode(metricName, forKey: .metricName)
        try values.encode(value, forKey: .value)
        try values.encode(tags, forKey: .tags)
        try values.encode(type.toString(), forKey: .type)
        
        let timestampString = timestamp.iso8601()
        try values.encode(timestampString, forKey: .timestamp)
    }
}
