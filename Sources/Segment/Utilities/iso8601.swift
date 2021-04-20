//
//  iso8601.swift
//  Segment
//
//  Created by Brandon Sneed on 12/8/20.
//

import Foundation

var __segment_isoDateFormatter = SegmentISO8601DateFormatter()

class SegmentISO8601DateFormatter: DateFormatter {
    override init() {
        super.init()
        
        self.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS:'Z'"
        self.locale = Locale(identifier: "en_US_POSIX")
        self.timeZone = TimeZone(secondsFromGMT: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

internal extension Date {
    // TODO: support nanoseconds
    func iso8601() -> String {
        return __segment_isoDateFormatter.string(from: self)
    }
}

internal extension String {
    func iso8601() -> Date? {
        return __segment_isoDateFormatter.date(from: self)
    }
}
