//
//  iso8601.swift
//  Segment
//
//  Created by Brandon Sneed on 12/8/20.
//

import Foundation

enum SegmentISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.update(with: .withFractionalSeconds)
        return formatter
    }()
}

internal extension Date {
    // TODO: support nanoseconds
    func iso8601() -> String {
        return SegmentISO8601DateFormatter.shared.string(from: self)
    }
}

internal extension String {
    func iso8601() -> Date? {
        return SegmentISO8601DateFormatter.shared.date(from: self)
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension JSONDecoder {
    static var `default`: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .formatted(DateFormatter.iso8601)
        return d
    }
}

extension JSONEncoder {
    static var `default`: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .formatted(DateFormatter.iso8601)
        return e
    }
}
