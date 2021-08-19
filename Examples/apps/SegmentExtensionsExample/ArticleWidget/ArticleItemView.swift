//
//   ArticleItemView.swift
//  SegmentExtensionsExample
//
//  Created by Alan Charles on 8/15/21.
//

import SwiftUI
import Segment

struct ArticleItemView: View {
    var article : Article
    
    var body: some View {
        HStack {
            Image(article.imageName)
                .resizable()
                .frame(width: 50, height: 50, alignment: .center)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(article.title)
                    .lineLimit(/*@START_MENU_TOKEN@*/2/*@END_MENU_TOKEN@*/)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                Text(article.source)
                    .lineLimit(1)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

