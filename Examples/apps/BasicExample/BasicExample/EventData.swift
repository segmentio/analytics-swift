//
//  EventData.swift
//  BasicExample
//
//  Created by Brandon Sneed on 5/24/21.
//

import Foundation
import Segment
import UIKit

struct UserTraits: Codable {
    let email: String
    let birthday: String
    let likesPho: Bool
}

struct TrackProperties: Codable {
    let dayOfWeek: String
}

struct ScreenProperties: Codable {
    let appUsage: TimeInterval
}


extension Date {
    func dayOfWeek() -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: self).capitalized
    }
}


class OutputPlugin: Plugin {
    let type: PluginType = .after
    let name: String
    
    var analytics: Analytics?
    var textView: UITextView!
    
    required init(name: String) {
        self.name = name
    }
    
    init(textView: UITextView!) {
        self.textView = textView
        self.name = "output_capture"
    }
    
    func execute<T>(event: T?) -> T? where T : RawEvent {
        let string = event?.prettyPrint()
        textView.text = string
        return event
    }
}
