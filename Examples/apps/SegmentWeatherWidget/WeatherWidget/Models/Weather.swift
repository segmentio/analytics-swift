//
//  Weather.swift
//  SegmentWeatherWidgetExample
//
//  Created by Alan Charles on 10/26/22.
//

import Foundation

struct Weather: Codable {
    let name: String
    let temperature: Int
    let unit: String
    let description: String
}

struct WeatherResponse: Codable {
    let forecast: [Weather]
}
