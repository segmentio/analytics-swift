//
//  SegmentSwiftUIExampleApp.swift
//  SegmentSwiftUIExample
//
//  Created by Cody Garvin on 5/24/21.
//

import SwiftUI
import Segment

@main
struct SegmentSwiftUIExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

extension Analytics {
    static var main = Analytics(configuration:
                                    Configuration(writeKey: "ABCD")
                                    .flushAt(3)
                                    .setTrackedApplicationLifecycleEvents(.all))
}
