//
//  MultiInstance.swift
//  SegmentUIKitExample
//
//  Created by Brandon Sneed on 4/8/21.
//

// NOTE: You can see this task in use in the SwiftUIKitExample application.

// MIT License
//
// Copyright (c) 2021 Segment
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Segment

/**
 An example of implementing multiple Analytics instances in a single application.
 */
extension Analytics {
    static var main = Analytics(configuration: Configuration(writeKey: "1234")
                                    .flushAt(3)
                                    .setTrackedApplicationLifecycleEvents(.all))

    static var support = Analytics(configuration: Configuration(writeKey: "5678")
                                    .flushAt(10)
                                    .setTrackedApplicationLifecycleEvents(.none))
}
