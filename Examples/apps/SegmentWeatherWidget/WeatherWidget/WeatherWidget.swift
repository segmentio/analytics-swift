//
//  WeatherWidget.swift
//  WeatherWidget
//
//  Created by Alan Charles on 10/26/22.
//

import Segment
import WidgetKit
import SwiftUI
import Intents

struct WeatherTimelineProvider: TimelineProvider {
    
    
    typealias Entry = WeatherEntry

    private func snapshotWeatherInfo() -> [Weather] {
        var weatherInfo = [Weather]()
        for i in 0...9 {
            let weather = Weather(name: "Day \(i + 1)", temperature: 10 * i, unit: "F", description: "Cloudy")
            weatherInfo.append(weather)
        }
        return weatherInfo
    }
    
    func placeholder(in context: TimelineProvider.Context) -> WeatherEntry {
        WeatherEntry(date: Date(), weatherInfo: snapshotWeatherInfo())
    }
    
    func getSnapshot(in context: TimelineProvider.Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(WeatherEntry(date: Date(), weatherInfo: snapshotWeatherInfo()))
    }
    
    func getTimeline(in context: TimelineProvider.Context, completion: @escaping (WidgetKit.Timeline<WeatherEntry>) -> Void) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        WeatherService().getWeather { result in
            let weatherInfo: [Weather]
            
            switch result {
            case  .success(let fetchedWeather):
                weatherInfo = fetchedWeather
            case .failure(let err):
                weatherInfo = [Weather(name: "Error", temperature: 0, unit: "", description: "\(err.localizedDescription)")]
            }
            
            let entry = WeatherEntry(date: currentDate, weatherInfo: weatherInfo)
            let timeline = WidgetKit.Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
}

struct WeatherEntry: TimelineEntry {
    let date: Date
    let weatherInfo: [Weather]
}

@main
struct WeatherWidget: Widget {
    let kind: String = "WeatherWidget"
    var analytics: Analytics?
    init() {
        let configuration = Segment.Configuration(writeKey: "WRITE_KEY")

        configuration.flushAt(1)
        analytics = Segment.Analytics(configuration: configuration)
        analytics?.track(name: "Widget Launched")
    }
    
    private let supportedFamilies:[WidgetFamily] = {
          if #available(iOSApplicationExtension 16.0, *) {
              return [.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryCircular, .accessoryRectangular]
          } else {
              return [.systemSmall, .systemMedium, .systemLarge]
          }
      }()

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherTimelineProvider()){ entry in
            WeatherEntryView(entry: entry)
        }
        .configurationDisplayName("SF Weather Widget")
        .description("This widget shows the current weather for SF.")
        .supportedFamilies(supportedFamilies)
    }
}
