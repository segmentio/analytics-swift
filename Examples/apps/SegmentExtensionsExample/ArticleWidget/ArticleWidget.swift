//
//  ArticleWidget.swift
//  ArticleWidget
//
//  Created by Alan Charles on 8/15/21.
//

import Segment
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {

    func placeholder(in context: TimelineProvider.Context) -> ArticleEntry {
        ArticleEntry(date: Date(),
                     libArticles: Article.libDocs,
                     destArticles: Article.destDocs)
    }

    func getSnapshot(in context: TimelineProvider.Context, completion: @escaping (ArticleEntry) -> ()) {
        let entry = ArticleEntry(date: Date(),
                                 libArticles: Article.libDocs,
                                 destArticles: Article.destDocs)
        completion(entry)
        
        Analytics.main.track(name:"Widget Snapshot")
    }

    func getTimeline(in context: TimelineProvider.Context, completion: @escaping (WidgetKit.Timeline<Entry>) -> ()) {
        var entries: [ArticleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = ArticleEntry(date: entryDate,
                                     libArticles: Article.libDocs,
                                     destArticles: Article.destDocs)
            entries.append(entry)
        }

        let timeline = WidgetKit.Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

}

struct ArticleEntry: TimelineEntry {
    let date: Date
    let libArticles: [Article]
    let destArticles: [Article]
}

struct ArticleWidgetEntryView : View {
    var entry: ArticleEntry
    
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArticleSectionView(sectionTitle: "Library Docs", articles: entry.libArticles)
            if widgetFamily == .systemLarge {
                ArticleSectionView(sectionTitle: "Destinations", articles: entry.destArticles)
            }
        }
        .padding(10)
    }
}

@main
struct ArticleWidget: Widget {
    let kind: String = "ArticleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ArticleWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemMedium, .systemLarge])
        .configurationDisplayName("Segment Documentation")
        .description("Documentation at your fingertips.")
    }
}

struct ArticleWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
        ArticleWidgetEntryView(entry: ArticleEntry(date: Date(),
                                                   libArticles: Article.libDocs,
                                                   destArticles: Article.destDocs))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        ArticleWidgetEntryView(entry: ArticleEntry(date: Date(),
                                                   libArticles: Article.libDocs,
                                                   destArticles: Article.destDocs))
            .previewContext(WidgetPreviewContext(family: .systemSmall))

    }
    }
}

extension Analytics {
    static var main = Analytics(configuration:
                                    Configuration(writeKey: "ABCD")
                                    .flushAt(3)
                                    .setTrackedApplicationLifecycleEvents(.all))
}
