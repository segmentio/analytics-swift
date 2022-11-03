//
//  Date+Extensions.swift
//  SegmentWeatherWidgetExample
//
//  Created by Alan Charles on 10/26/22.
//

import Foundation


extension Date {
    func timeOnly() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        
        return formatter.string(from: self)
    }
    
    func timeSinceDate() -> String {
        let fromDate = self
        let toDate = Date()
        
        // Year
        if let interval = Calendar.current.dateComponents([.year], from: fromDate, to: toDate).year, interval > 0 {
            return interval == 1 ? "\(interval)" + "" + "year ago": "\(interval)" + "" + "years ago"
        }
        
        // Month
        if let interval = Calendar.current.dateComponents([.month], from: fromDate, to: toDate).month, interval > 0 {
            return interval == 1 ? "\(interval)" + "" + "month ago" : "\(interval)" + "" + "months ago"
         }
        
        // Day
        if let interval = Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day, interval > 0 {
            return interval == 1 ? "\(interval)" + "" + "day ago" : "\(interval)" + "" + "days ago"
         }
        
        // Hour
        if let interval = Calendar.current.dateComponents([.hour], from: fromDate, to: toDate).hour, interval > 0 {
            return interval == 1 ? "\(interval)" + "" + "hour ago" : "\(interval)" + "" + "hours ago"
         }
        
        // Minute
        if let interval = Calendar.current.dateComponents([.minute], from: fromDate, to: toDate).minute, interval > 0 {
            return interval == 1 ? "\(interval)" + "" + "minute ago" : "\(interval)" + "" + "minutes ago"
         }
        
        return "a moment ago"
    }
    
}
