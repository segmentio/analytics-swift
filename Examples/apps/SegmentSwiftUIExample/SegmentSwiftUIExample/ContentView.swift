//
//  ContentView.swift
//  SegmentSwiftUIExample
//
//  Created by Cody Garvin on 5/24/21.
//

import SwiftUI
import Segment

struct ContentView: View {
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    Analytics.main.track(name: "Track")
                }, label: {
                    Text("Track")
                }).padding(6)
                Button(action: {
                    Analytics.main.screen(title: "Screen appeared")
                }, label: {
                    Text("Screen")
                }).padding(6)
            }.padding(8)
            HStack {
                Button(action: {
                    Analytics.main.group(groupId: "12345-Group")
                }, label: {
                    Text("Group")
                }).padding(6)
                Button(action: {
                    Analytics.main.identify(userId: "X-1234567890")
                }, label: {
                    Text("Identify")
                }).padding(6)
            }.padding(8)
        }.onAppear {
            Analytics.main.track(name: "onAppear")
            print("Executed Analytics onAppear()")
        }.onDisappear {
            Analytics.main.track(name: "onDisappear")
            print("Executed Analytics onDisappear()")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
