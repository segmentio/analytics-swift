//
//  Storage.swift
//  Segment
//
//  Created by Brandon Sneed on 1/5/21.
//

import Foundation
import Sovran

internal class Storage: Subscriber {
    let store: Store
    let writeKey: String
    let syncQueue = DispatchQueue(label: "storage.segment.com")
    let userDefaults: UserDefaults?
    static let MAXFILESIZE = 475000     // Server accepts max 500k per batch
    
    private var fileHandle: FileHandle? = nil
    
    init(store: Store, writeKey: String) {
        self.store = store
        self.writeKey = writeKey
        self.userDefaults = UserDefaults(suiteName: "com.segment.storage.\(writeKey)")
        store.subscribe(self, handler: userInfoUpdate)
        store.subscribe(self, handler: systemUpdate)
    }
}

// MARK: - String Contants

extension Storage {
    static let tempExtension = "temp"
    
    enum Constants: String, CaseIterable {
        case userId = "segment.userId"
        case traits = "segment.traits"
        case anonymousId = "segment.anonymousId"
        case settings = "segment.settings"
        case events = "segment.events"
    }
}

// MARK: - Read/Write

extension Storage {
    func write<T: Codable>(_ key: Storage.Constants, value: T?) {
        switch key {
        case .events:
            if let event = value as? RawEvent {
                let eventStoreFile = currentFile(key)
                self.storeEvent(toFile: eventStoreFile, event: event)
            }
            break
        default:
            if isBasicType(value: value) {
                // we can write it like normal
                userDefaults?.set(value, forKey: key.rawValue)
            } else {
                // encode it to a data object to store
                let encoder = PropertyListEncoder()
                if let plistValue = try? encoder.encode(value) {
                    userDefaults?.set(plistValue, forKey: key.rawValue)
                }
            }
        }
        userDefaults?.synchronize()
    }
    
    func read(_ key: Storage.Constants) -> [URL]? {
        switch key {
        case .events:
            return eventFiles(includeUnfinished: false)
        default:
            break
        }
        return nil
    }
    
    func read<T: Codable>(_ key: Storage.Constants) -> T? {
        var result: T? = nil
        switch key {
        case .events:
            // do nothing
            break
        default:
            let decoder = PropertyListDecoder()
            let raw = userDefaults?.object(forKey: key.rawValue)
            if let r = raw as? Data {
                // it's an encoded object, not a basic type
                result = try? decoder.decode(T.self, from: r)
            } else {
                // it's a basic type
                result = userDefaults?.object(forKey: key.rawValue) as? T
            }
        }
        return result
    }
    
    func hardReset(doYouKnowHowToUseThis: Bool) {
        if doYouKnowHowToUseThis != true { return }

        let urls = eventFiles(includeUnfinished: true)
        for key in Constants.allCases {
            // on linux, setting a key's value to nil just deadlocks.
            // however just removing it works, which is what we really
            // wanna do anyway.
            userDefaults?.removeObject(forKey: key.rawValue)
        }

        for url in urls {
            try? FileManager.default.removeItem(atPath: url.path)
        }
    }
    
    func isBasicType<T: Codable>(value: T?) -> Bool {
        var result = false
        if value == nil {
            result = true
        } else {
            switch value {
            case is NSNull:
                fallthrough
            case is Decimal:
                fallthrough
            case is NSNumber:
                fallthrough
            case is Bool:
                fallthrough
            case is String:
                result = true
            default:
                break
            }
        }
        return result
    }
    
    func currentFile(_ key: Storage.Constants) -> URL {
        var currentFile = 0
        syncQueue.sync {
            let index: Int = userDefaults?.integer(forKey: key.rawValue) ?? 0
            userDefaults?.set(index, forKey: key.rawValue)
            currentFile = index
        }
        return self.eventsFile(index: currentFile)
    }
}

// MARK: - State Subscriptions

extension Storage {
    func userInfoUpdate(state: UserInfo) {
        // write new stuff to disk
        write(.userId, value: state.userId)
        write(.traits, value: state.traits)
        write(.anonymousId, value: state.anonymousId)
    }
    
    func systemUpdate(state: System) {
        // write new stuff to disk
        if let s = state.settings {
            write(.settings, value: s)
        }
    }
}

// MARK: - Utility Methods

extension Storage {
    func eventStorageDirectory() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docURL = urls[0]
        let segmentURL = docURL.appendingPathComponent("segment/\(writeKey)/")
        // try to create it, will fail if already exists, nbd.
        // tvOS, watchOS regularly clear out data.
        try? FileManager.default.createDirectory(at: segmentURL, withIntermediateDirectories: true, attributes: nil)
        return segmentURL
    }
    
    func eventsFile(index: Int) -> URL {
        let docs = eventStorageDirectory()
        let fileURL = docs.appendingPathComponent("\(index)-segment-events")
        return fileURL
    }
    
    func eventFiles(includeUnfinished: Bool) -> [URL] {
        // synchronized against finishing/creating files while we're getting
        // a list of files to send.
        
        // finish out any file in progress
        var index: Int = 0
        syncQueue.sync {
            index = userDefaults?.integer(forKey: Constants.events.rawValue) ?? 0
        }
        finish(file: eventsFile(index: index))
        
        var result = [URL]()
        syncQueue.sync {
            let allFiles = try? FileManager.default.contentsOfDirectory(at: eventStorageDirectory(), includingPropertiesForKeys: [], options: .skipsHiddenFiles)
            var files = allFiles
            
            if includeUnfinished == false {
                files = allFiles?.filter({ (file) -> Bool in
                    return file.pathExtension == Storage.tempExtension
                })
            }
            
            let sorted = files?.sorted { (left, right) -> Bool in
                return left.lastPathComponent > right.lastPathComponent
            }
            if let s = sorted {
                result = s
            }
        }
        return result
    }
}

// MARK: - Event Storage

extension Storage {
    
    func storeEvent(toFile file: URL, event: RawEvent) {
        
        var storeFile = file
        
        let fm = FileManager.default
        var newFile = false
        if fm.fileExists(atPath: storeFile.path) == false {
            start(file: storeFile)
            newFile = true
        }
        
        // Verify file size isn't too large
        if let attributes = try? fm.attributesOfItem(atPath: storeFile.path),
           let fileSize = attributes[FileAttributeKey.size] as? UInt64,
           fileSize >= Storage.MAXFILESIZE {
            finish(file: storeFile)
            // Set the new file path
            storeFile = currentFile(.events)
            start(file: storeFile)
            newFile = true
        }
        
        syncQueue.sync {
            let jsonString = event.toString()
            if let jsonData = jsonString.data(using: .utf8) {
                fileHandle?.seekToEndOfFile()
                // prepare for the next entry
                if newFile == false {
                    fileHandle?.write(",".data(using: .utf8)!)
                }
                // write the data
                fileHandle?.write(jsonData)
                if #available(tvOS 13, *) {
                    try? fileHandle?.synchronize()
                }
            } else {
                assert(false, "Storage: Unable to convert event to json!")
            }
        }
    }
    
    func start(file: URL) {
        syncQueue.sync {
            let contents = "{ \"batch\": ["
            do {
                FileManager.default.createFile(atPath: file.path, contents: contents.data(using: .utf8))
                fileHandle = try FileHandle(forWritingTo: file)
            } catch {
                assert(false, "Storage: failed to write \(file), error: \(error)")
            }
        }
    }
    
    func finish(file: URL) {
        syncQueue.sync {
            let sentAt = Date().iso8601()

            // write it to the existing file
            let fileEnding = "],\"sentAt\":\"\(sentAt)\"}"
            let endData = fileEnding.data(using: .utf8)
            if let endData = endData {
                fileHandle?.seekToEndOfFile()
                fileHandle?.write(endData)
                if #available(tvOS 13, *) {
                    try? fileHandle?.synchronize()
                }
                fileHandle?.closeFile()
                fileHandle = nil
            } else {
                // something is wrong with this file, maybe delete it?
                //assert(false, "Storage: event storage \(file) is messed up!")
            }

            let tempFile = file.appendingPathExtension(Storage.tempExtension)
            try? FileManager.default.copyItem(at: file, to: tempFile)

            let currentFile: Int = (userDefaults?.integer(forKey: Constants.events.rawValue) ?? 0) + 1
            userDefaults?.set(currentFile, forKey: Constants.events.rawValue)
        }
    }
    
    func remove(file: URL) {
        syncQueue.sync {
            // remove the temp file.
            try? FileManager.default.removeItem(atPath: file.path)
            // remove the unfinished event storage file.
            let actualFile = file.deletingPathExtension()
            try? FileManager.default.removeItem(atPath: actualFile.path)
        }
    }
}
