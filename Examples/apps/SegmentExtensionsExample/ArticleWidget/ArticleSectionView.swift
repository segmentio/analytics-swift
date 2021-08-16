//
//  ArticleSectionView.swift
//  SegmentExtensionsExample
//
//  Created by Alan Charles on 8/15/21.
//

import SwiftUI
import Segment

struct ArticleSectionView: View {
    
    var sectionTitle: String
    var articles: [Article]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle)
                .font(.subheadline)
                .fontWeight(.heavy)
                .foregroundColor(Color.blue)
            ArticleItemView(article: articles[0])
            ArticleItemView(article: articles[1])
        }
    }
}

