//
//  ConsoleTarget.swift
//  ConsoleTarget
//
//  Created by Cody Garvin on 8/19/21.
//

import Foundation

class ConsoleTarget: LogTarget {
    func parseLog(_ log: LogMessage) {
        var metadata = ""
        if let function = log.function, let line = log.line {
            metadata = " - \(function):\(line)"
        }
        print("[Segment \(log.kind.toString())\(metadata)]\n\(log.message)\n")
    }
}
