//
//  File.swift
//  
//
//  Created by Brandon Sneed on 11/30/23.
//

import Foundation

extension FileHandle {
    static func createIfNecessary(url: URL) throws -> URL {
        if FileManager.default.fileExists(atPath: url.path) == false {
            let basePath = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
            let success = FileManager.default.createFile(atPath: url.path, contents: nil)
            if !success {
                throw NSError(domain: "Unable to create file, \(url)", code: 42)
            }
        }
        return url
    }
}
