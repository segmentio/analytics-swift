//
//  Errors.swift
//  
//
//  Created by Brandon Sneed on 10/20/22.
//

import Foundation

public enum AnalyticsError: Error {
    case storageUnableToCreate(String)
    case storageUnableToWrite(String)
    case storageUnableToRename(String)
    case storageUnableToOpen(String)
    case storageUnableToClose(String)
    case storageInvalid(String)
    case storageUnknown(Error)

    case networkUnexpectedHTTPCode(Int)
    case networkServerLimited(Int)
    case networkServerRejected(Int)
    case networkUnknown(Error)
    case networkInvalidData

    case jsonUnableToSerialize(Error)
    case jsonUnableToDeserialize(Error)
    case jsonUnknown(Error)

    case pluginError(Error)
}

extension Analytics {
    /// Tries to convert known error types to AnalyticsError.
    static internal func translate(error: Error) -> Error {
        if let e = error as? OutputFileStream.OutputStreamError {
            switch e {
            case .invalidPath(let path):
                return AnalyticsError.storageInvalid(path)
            case .unableToCreate(let path):
                return AnalyticsError.storageUnableToCreate(path)
            case .unableToOpen(let path):
                return AnalyticsError.storageUnableToOpen(path)
            case .unableToWrite(let path):
                return AnalyticsError.storageUnableToWrite(path)
            case .unableToClose(let path):
                return AnalyticsError.storageUnableToClose(path)
            }
        }
        
        if let e = error as? JSON.JSONError {
            switch e {
            case .incorrectType:
                return AnalyticsError.jsonUnableToDeserialize(e)
            case .nonJSONType:
                return AnalyticsError.jsonUnableToDeserialize(e)
            case .unknown:
                return AnalyticsError.jsonUnknown(e)
            }
        }
        return error
    }
    
    /// Reports an internal error to the user-defined error handler.
    public func reportInternalError(_ error: Error, fatal: Bool = false) {
        let translatedError = Self.translate(error: error)
        configuration.values.errorHandler?(translatedError)
        Self.segmentLog(message: "An internal error occurred: \(translatedError)", kind: .error)
        if fatal {
            exceptionFailure("A critical error occurred: \(translatedError)")
        }
    }
    
    static public func reportInternalError(_ error: Error, fatal: Bool = false) {
        // we don't have an instance of analytics to call to get our error handler,
        // but we can at least report the message to the console.
        let translatedError = Self.translate(error: error)
        Self.segmentLog(message: "An internal error occurred: \(translatedError)", kind: .error)
        if fatal {
            exceptionFailure("A critical error occurred: \(translatedError)")
        }
    }
}
