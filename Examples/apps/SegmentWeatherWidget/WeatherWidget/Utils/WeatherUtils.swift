//
//  WeatherUtils.swift
//  SegmentWeatherWidgetExample
//
//  Created by Alan Charles on 10/26/22.
//

import Foundation

struct WeatherUtils {
    static func getWeatherIcon(_ conditionString: String) -> String {
        let current = conditionString.lowercased()
        switch current {
        case _ where current.contains("partly sunny"):
            return "🌤️"
            
        case _ where current.contains("light rain"):
            return "☔️"
            
        case _ where current.contains("cloudy"):
            return "☁️"
            
        case _ where current.contains("drizzle"):
            return "🌧️"
            
        case _ where current.contains("sunny"):
            return "☀️"
            
        case _ where current.contains("clear"):
            return "☀️"
            
        case _ where current.contains("fog"):
            return "🌫️"
            
        default:
            return "🌤️"
        }
    }
}
