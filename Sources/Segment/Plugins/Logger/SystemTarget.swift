//
//  File.swift
//  File
//
//  Created by Cody Garvin on 8/20/21.
//

#if !os(Linux)

import Foundation
import os.log

class SystemTarget: LogTarget {
    
    static let logCategory = OSLog(subsystem: "Segment", category: "Log")
    static let metricsCategory = OSLog(subsystem: "Segment", category: "Metrics")
    static let historyCategory = OSLog(subsystem: "Segment", category: "History")
    
    func parseLog(_ log: LogMessage) {
        var metadata = ""
        if let function = log.function, let line = log.line {
            metadata = " - \(function):\(line)"
        }
                
        os_log("[Segment %{public}@ %{public}@]\n%{public}@\n",
               log: categoryFor(log: log),
               type: osLogTypeFromFilterKind(kind: log.kind),
               log.kind.toString(), metadata, log.message) // need to fix type
    }
    
    private func categoryFor(log: LogMessage) -> OSLog {
        switch log.logType {
            case .log:
                return SystemTarget.logCategory
            case .metric:
                return SystemTarget.metricsCategory
            case .history:
                return SystemTarget.historyCategory
        }
    }
    
    private func osLogTypeFromFilterKind(kind: LogFilterKind) -> OSLogType {
        var osLogType: OSLogType
        switch kind {
            case .debug:
                osLogType = .info
            case .warning:
                osLogType = .debug
            case .error:
                osLogType = .error
        }
        return osLogType
    }
}

#endif
