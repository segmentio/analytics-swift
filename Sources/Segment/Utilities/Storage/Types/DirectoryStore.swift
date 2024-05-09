//
//  File.swift
//  
//
//  Created by Brandon Sneed on 3/2/24.
//

import Foundation

public class DirectoryStore: DataStore {
    internal static var fileValidator: ((URL) -> Void)? = nil
    
    public typealias StoreConfiguration = Configuration
    
    public struct Configuration {
        let writeKey: String
        let storageLocation: URL
        let baseFilename: String
        let maxFileSize: Int
        let indexKey: String
        
        public init(writeKey: String, storageLocation: URL, baseFilename: String, maxFileSize: Int, indexKey: String) {
            self.writeKey = writeKey
            self.storageLocation = storageLocation
            self.baseFilename = baseFilename
            self.maxFileSize = maxFileSize
            self.indexKey = indexKey
        }
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
    
    public var transactionType: DataTransactionType {
        return .file
    }
    
    static let tempExtension = "temp"
    internal let config: Configuration
    internal var writer: LineStreamWriter? = nil
    internal let userDefaults: UserDefaults
    
    public required init(configuration: Configuration) {
        try? FileManager.default.createDirectory(at: configuration.storageLocation, withIntermediateDirectories: true)
        self.config = configuration
        self.userDefaults = UserDefaults(suiteName: "com.segment.storage.\(config.writeKey)")!
    }
    
    public func reset() {
        let files = sortedFiles(includeUnfinished: true)
        remove(data: files)
    }
    
    public func append(data: RawEvent) {
        let started = startFileIfNeeded()
        guard let writer else { return }
        
        let line = data.toString()
        
        // check if we're good on size ...
        if writer.bytesWritten >= config.maxFileSize {
            // it's too big, end it.
            finishFile()
            // start over with the data we not writing.
            append(data: data)
            return
        }
        
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
            return DataResult(dataFiles: data, removable: data)
        }
        return nil
    }
    
    public func remove(data: [DataStore.ItemID]) {
        guard let urls = data as? [URL] else { return }
        for file in urls {
            try? FileManager.default.removeItem(at: file)
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
        
        // do validation before we rename to prevent the file disappearing out from under us.
        DirectoryStore.fileValidator?(url)
        
        // move it to make availble for flushing ...
        let newURL = url.appendingPathExtension(Self.tempExtension)
        try? FileManager.default.moveItem(at: url, to: newURL)
        self.writer = nil
        incrementIndex()
    }
}

extension DirectoryStore {
    func getIndex() -> Int {
        let index: Int = userDefaults.integer(forKey: config.indexKey)
        return index
    }
    
    func incrementIndex() {
        let index: Int = userDefaults.integer(forKey: config.indexKey) + 1
        userDefaults.set(index, forKey: config.indexKey)
        userDefaults.synchronize()
    }
}
