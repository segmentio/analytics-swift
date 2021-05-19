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
                // this is synchronized against finish(file:) down below.
                var currentFile = 0
                syncQueue.sync {
                    let index: Int = userDefaults?.integer(forKey: key.rawValue) ?? 0
                    userDefaults?.set(index, forKey: key.rawValue)
                    currentFile = index
                }
                self.storeEvent(toFile: self.eventsFile(index: currentFile), event: event)
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
            userDefaults?.set(nil, forKey: key.rawValue)
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
        let fm = FileManager.default
        var newFile = false
        if fm.fileExists(atPath: file.path) == false {
            start(file: file)
            newFile = true
        }
        
        syncQueue.sync {
            do {
                let jsonString = event.toString()
                if let jsonData = jsonString.data(using: .utf8) {
                    let handle = try FileHandle(forWritingTo: file)
                    handle.seekToEndOfFile()
                    // prepare for the next entry
                    if newFile == false {
                        handle.write(",".data(using: .utf8)!)
                    }
                    // write the data
                    handle.write(jsonData)
                    handle.closeFile()
                } else {
                    assert(false, "Storage: Unable to convert event to json!")
                }
            } catch {
                assert(false, "Storage: failed to write event to \(file), error: \(error)")
            }
        }
    }
    
    func start(file: URL) {
        syncQueue.sync {
            let contents = "{ \"batch\": ["
            do {
                try contents.write(toFile: file.path, atomically: true, encoding: .utf8)
            } catch {
                assert(false, "Storage: failed to write \(file), error: \(error)")
            }
        }
    }
    
    func finish(file: URL) {
        syncQueue.sync {
            let tempFile = file.appendingPathExtension(Storage.tempExtension)
            try? FileManager.default.copyItem(at: file, to: tempFile)
            
            let sentAt = Date().iso8601()

            // write it to the existing file
            let fileEnding = "],\"sentAt\":\"\(sentAt)\"}"
            let endData = fileEnding.data(using: .utf8)
            if let endData = endData, let handle = try? FileHandle(forWritingTo: tempFile) {
                handle.seekToEndOfFile()
                handle.write(endData)
                handle.closeFile()
            } else {
                // something is wrong with this file, maybe delete it?
                //assert(false, "Storage: event storage \(file) is messed up!")
            }
            
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
