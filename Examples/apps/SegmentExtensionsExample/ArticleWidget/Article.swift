//
//  Article.swift
//  SegmentExtensionsExample
//
//  Created by Alan Charles on 8/15/21.
//

import Foundation
import Segment

struct Article {
    let title: String
    let source: String
    let imageName: String
}

extension Article {
    
    private static let availableLibDocs = [
        Article(title:"Analytics for iOS ", source: "https://segment.com/docs/connections/sources/catalog/libraries/mobile/ios/#analytics-for-ios", imageName: "Segment_logo"),
        Article(title:"Analytics for Android", source: "https://segment.com/docs/connections/sources/catalog/libraries/mobile/android/", imageName: "Segment_logo"),
        Article(title:"Analytics for React Native", source: "https://segment.com/docs/connections/sources/catalog/libraries/mobile/react-native/", imageName: "Segment_logo"),
        Article(title:"Analytics.js", source: "https://segment.com/docs/connections/sources/catalog/libraries/website/javascript/", imageName: "Segment_logo"),
        Article(title:"Analytics for Node ", source: "https://segment.com/docs/connections/sources/catalog/libraries/server/node/", imageName: "Segment_logo"),
    ]
    
    private static let availableDestDocs = [
        Article(title:"Appsflyer Destination", source: "https://segment.com/docs/connections/destinations/catalog/appsflyer/", imageName: "Segment_logo"),
        Article(title:"Firebase Destination", source: "https://segment.com/docs/connections/destinations/catalog/firebase/", imageName: "Segment_logo"),
        Article(title:"Facebook App Events Destination", source: "https://segment.com/docs/connections/destinations/catalog/facebook-app-events/", imageName: "Segment_logo"),
        Article(title:"Mixpanel Destination", source: "https://segment.com/docs/connections/destinations/catalog/mixpanel/", imageName: "Segment_logo"),
        Article(title:"Amplitude Destination", source: "https://segment.com/docs/connections/destinations/catalog/Amplitude/", imageName: "Segment_logo"),
        
    ]
    
    static var libDocs: [Article] {
        return Array(availableLibDocs.shuffled().prefix(2))
    }
    
    static var destDocs: [Article] {
        return Array(availableDestDocs.shuffled().prefix(2))
    }
}
