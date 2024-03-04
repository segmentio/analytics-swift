//
//  File.swift
//  
//
//  Created by Brandon Sneed on 3/2/24.
//

import Foundation

internal class DirectoryStore: DataStore {
    typealias StoreConfiguration = Configuration
    
    public struct Configuration {
        let writeKey: String
        let storageLocation: URL
        let baseFilename: String
        let maxFileSize: Int
        let userDefaults: UserDefaults
        let indexKey: String
    }
    
    public var hasData: Bool {
        return count > 0
    }
    
    public var count: Int {
        if let r = try? FileManager.default.contentsOfDirectory(at: config.storageLocation, includingPropertiesForKeys: nil) {
            return r.count
        }
        return 0
    }
    
    static let tempExtension = "temp"
    internal let config: Configuration
    internal var writer: LineStreamWriter? = nil
    
    public required init(configuration: Configuration) {
        try? FileManager.default.createDirectory(at: configuration.storageLocation, withIntermediateDirectories: true)
        self.config = configuration
    }
    
    public func reset() {
        let files = sortedFiles(includeUnfinished: true).hashValues
        remove(data: files)
    }
    
    public func append<T>(data: T) where T : Decodable, T : Encodable {
        let started = startFileIfNeeded()
        guard let writer else { return }
        
        let encoder = JSONEncoder()
        guard let d = try? encoder.encode(data) else { return }
        
        // check if we're good on size ...
        if writer.bytesWritten >= config.maxFileSize {
            // it's too big, end it.
            finishFile()
            // start over with the data we not writing.
            append(data: data)
            return
        }
        
        guard let line = String(data: d, encoding: .utf8) else { return }
        do {
            if started {
                try writer.writeLine(line)
            } else {
                try writer.writeLine("," + line)
            }
        } catch {
            print(error)
        }
    }
    
    public func fetch(count: Int?, maxBytes: Int?) -> DataResult? {
        if writer != nil {
            finishFile()
        }
        let sorted = sortedFiles()
        var data = sorted
        
        if let maxBytes {
            data = upToSize(max: UInt64(maxBytes), files: data)
        }
        
        if let count, count <= data.count {
            data = Array(data[0..<count])
        }
        
        if data.count > 0 {
            return DataResult(dataFiles: data, removable: data.hashValues)
        }
        return nil
    }
    
    public func remove(data: [DataStore.HashValue]) {
        let urls = sortedFiles(includeUnfinished: true)
        for file in urls {
            if data.contains(file.hashValue) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

extension DirectoryStore {
    func sortedFiles(includeUnfinished: Bool = false) -> [URL] {
        guard let allFiles = try? FileManager.default.contentsOfDirectory(at: config.storageLocation, includingPropertiesForKeys: nil) else {
            return []
        }
        let files = allFiles.filter { file in
            if includeUnfinished {
                return true
            }
            return file.pathExtension == Self.tempExtension
        }
        let sorted = files.sorted { left, right in
            return left.lastPathComponent < right.lastPathComponent
        }
        return sorted
    }
    
    func upToSize(max: UInt64, files: [URL]) -> [URL] {
        var result = [URL]()
        var accumulatedSize: UInt64 = 0
        
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path) {
                guard let s = attrs[FileAttributeKey.size] as? Int else { continue }
                let size = UInt64(s)
                if accumulatedSize + size < max {
                    result.append(file)
                    accumulatedSize += size
                }
            }
        }
        return result
    }
    
    @inline(__always)
    func startFileIfNeeded() -> Bool {
        guard writer == nil else { return false }
        let index = getIndex()
        let fileURL = config.storageLocation.appendingPathComponent("\(index)-\(config.baseFilename)")
        writer = LineStreamWriter(url: fileURL)
        // we might be reopening this file .. so only do this if it's empty.
        if let writer, writer.bytesWritten == 0 {
            let contents = "{ \"batch\": ["
            try? writer.writeLine(contents)
            return true
        }
        return false
    }
    
    func finishFile() {
        guard let writer else {
            #if DEBUG
            assertionFailure("There's no working file!")
            #endif
            return
        }
        
        let sentAt = Date().iso8601()
        let fileEnding = "],\"sentAt\":\"\(sentAt)\",\"writeKey\":\"\(config.writeKey)\"}"
        try? writer.writeLine(fileEnding)
        
        let url = writer.url
        let newURL = url.appendingPathExtension(Self.tempExtension)
        try? FileManager.default.moveItem(at: url, to: newURL)
        self.writer = nil
        incrementIndex()
    }
}

extension DirectoryStore {
    func getIndex() -> Int {
        let index: Int = config.userDefaults.integer(forKey: config.indexKey)
        return index
    }
    
    func incrementIndex() {
        let index: Int = config.userDefaults.integer(forKey: config.indexKey) + 1
        config.userDefaults.set(index, forKey: config.indexKey)
    }
}
