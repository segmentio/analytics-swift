//
//  Storage.swift
//  Segment
//
//  Created by Brandon Sneed on 1/5/21.
//

import Foundation
import Sovran

internal class Storage: Subscriber {
    let writeKey: String
    let userDefaults: UserDefaults?
    static let MAXFILESIZE = 475000 // Server accepts max 500k per batch

    // This queue synchronizes reads/writes.
    // Do NOT use it outside of: write, read, reset, remove.
    let syncQueue = DispatchQueue(label: "sync.segment.com")

    private var outputStream: OutputFileStream? = nil
    
    internal var onFinish: ((URL) -> Void)? = nil
    internal weak var analytics: Analytics? = nil
    
    init(store: Store, writeKey: String) {
        self.writeKey = writeKey
        self.userDefaults = UserDefaults(suiteName: "com.segment.storage.\(writeKey)")
        store.subscribe(self) { [weak self] (state: UserInfo) in
            self?.userInfoUpdate(state: state)
        }
        store.subscribe(self) { [weak self] (state: System) in
            self?.systemUpdate(state: state)
        }
    }
    
    func write<T: Codable>(_ key: Storage.Constants, value: T?) {
        syncQueue.sync {
            switch key {
            case .events:
                if let event = value as? RawEvent {
                    let eventStoreFile = currentFile(key)
                    self.storeEvent(toFile: eventStoreFile, event: event)
                    if let flushPolicies = analytics?.configuration.values.flushPolicies {
                        for policy in flushPolicies {
                            policy.updateState(event: event)

                            if (policy.shouldFlush() == true) {
                                policy.reset()
                            }
                        }
                    }
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
    }
    
    func read(_ key: Storage.Constants) -> [URL]? {
        var result: [URL]? = nil
        syncQueue.sync {
            switch key {
            case .events:
                result = eventFiles(includeUnfinished: false)
            default:
                break
            }
        }
        return result
    }
    
    func read<T: Codable>(_ key: Storage.Constants) -> T? {
        var result: T? = nil
        syncQueue.sync {
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
        }
        return result
    }
    
    static func hardSettingsReset(writeKey: String) {
        guard let defaults = UserDefaults(suiteName: "com.segment.storage.\(writeKey)") else { return }
        defaults.removeObject(forKey: Constants.anonymousId.rawValue)
        defaults.removeObject(forKey: Constants.settings.rawValue)
        print(Array(defaults.dictionaryRepresentation().keys).count)
    }
    
    func hardReset(doYouKnowHowToUseThis: Bool) {
        syncQueue.sync {
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
    }
    
    func isBasicType<T: Codable>(value: T?) -> Bool {
        var result = false
        if value == nil {
            result = true
        } else {
            switch value {
            // NSNull is not valid for UserDefaults
            //case is NSNull:
            //    fallthrough
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
    
    func remove(file: URL) {
        syncQueue.sync {
            // remove the temp file.
            try? FileManager.default.removeItem(atPath: file.path)
        }
    }

}

// MARK: - String Contants

extension Storage {
    private static let tempExtension = "temp"
    
    enum Constants: String, CaseIterable {
        case userId = "segment.userId"
        case traits = "segment.traits"
        case anonymousId = "segment.anonymousId"
        case settings = "segment.settings"
        case events = "segment.events"
    }
}

// MARK: - State Subscriptions

extension Storage {
    internal func userInfoUpdate(state: UserInfo) {
        // write new stuff to disk
        write(.userId, value: state.userId)
        write(.traits, value: state.traits)
        write(.anonymousId, value: state.anonymousId)
    }
    
    internal func systemUpdate(state: System) {
        // write new stuff to disk
        if let s = state.settings {
            write(.settings, value: s)
        }
    }
}

// MARK: - Utility Methods

extension Storage {
    private func currentFile(_ key: Storage.Constants) -> URL {
        var currentFile = 0
        let index: Int = userDefaults?.integer(forKey: key.rawValue) ?? 0
        userDefaults?.set(index, forKey: key.rawValue)
        currentFile = index
        return self.eventsFile(index: currentFile)
    }
    
    private func eventStorageDirectory() -> URL {
        #if os(tvOS) || os(macOS)
        let searchPathDirectory = FileManager.SearchPathDirectory.cachesDirectory
        #else
        let searchPathDirectory = FileManager.SearchPathDirectory.documentDirectory
        #endif
        
        let urls = FileManager.default.urls(for: searchPathDirectory, in: .userDomainMask)
        let docURL = urls[0]
        let segmentURL = docURL.appendingPathComponent("segment/\(writeKey)/")
        // try to create it, will fail if already exists, nbd.
        // tvOS, watchOS regularly clear out data.
        try? FileManager.default.createDirectory(at: segmentURL, withIntermediateDirectories: true, attributes: nil)
        return segmentURL
    }
    
    private func eventsFile(index: Int) -> URL {
        let docs = eventStorageDirectory()
        let fileURL = docs.appendingPathComponent("\(index)-segment-events")
        return fileURL
    }
    
    internal func eventFiles(includeUnfinished: Bool) -> [URL] {
        // synchronized against finishing/creating files while we're getting
        // a list of files to send.
        var result = [URL]()

        // finish out any file in progress
        let index = userDefaults?.integer(forKey: Constants.events.rawValue) ?? 0
        finish(file: eventsFile(index: index))
        
        let allFiles = try? FileManager.default.contentsOfDirectory(at: eventStorageDirectory(), includingPropertiesForKeys: [], options: .skipsHiddenFiles)
        var files = allFiles
        
        if includeUnfinished == false {
            files = allFiles?.filter { (file) -> Bool in
                return file.pathExtension == Storage.tempExtension
            }
        }
        
        let sorted = files?.sorted { (left, right) -> Bool in
            return left.lastPathComponent > right.lastPathComponent
        }
        if let s = sorted {
            result = s
        }
        return result
    }
}

// MARK: - Event Storage

extension Storage {
    private func storeEvent(toFile file: URL, event: RawEvent) {
        var storeFile = file
        
        let fm = FileManager.default
        var newFile = false
        if fm.fileExists(atPath: storeFile.path) == false {
            start(file: storeFile)
            newFile = true
        } else if outputStream == nil {
            // this can happen if an instance was terminated before finishing a file.
            open(file: storeFile)
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
        
        let jsonString = event.toString()
        do {
            if outputStream == nil {
                Analytics.segmentLog(message: "Storage: Output stream is nil for \(storeFile)", kind: .error)
            }
            if newFile == false {
                // prepare for the next entry
                try outputStream?.write(",")
            }
            try outputStream?.write(jsonString)
        } catch {
            analytics?.reportInternalError(error)
        }
    }
    
    private func start(file: URL) {
        let contents = "{ \"batch\": ["
        do {
            outputStream = try OutputFileStream(fileURL: file)
            try outputStream?.create()
            try outputStream?.write(contents)
        } catch {
            analytics?.reportInternalError(error)
        }
    }
    
    private func open(file: URL) {
        if outputStream == nil {
            // this can happen if an instance was terminated before finishing a file.
            do {
                outputStream = try OutputFileStream(fileURL: file)
            } catch {
                analytics?.reportInternalError(error)
            }
        }

        if let outputStream = outputStream {
            do {
                try outputStream.open()
            } catch {
                analytics?.reportInternalError(error)
            }
        }
    }
    
    private func finish(file: URL) {
        guard let outputStream = self.outputStream else {
            // we haven't actually started a file yet and being told to flush
            // so ignore it and get out.
            return
        }
        
        let sentAt = Date().iso8601()

        // write it to the existing file
        let fileEnding = "],\"sentAt\":\"\(sentAt)\",\"writeKey\":\"\(writeKey)\"}"
        do {
            try outputStream.write(fileEnding)
            try outputStream.close()
        } catch {
            analytics?.reportInternalError(error)
        }
        
        self.outputStream = nil

        let tempFile = file.appendingPathExtension(Storage.tempExtension)
        do {
            try FileManager.default.moveItem(at: file, to: tempFile)
        } catch {
            analytics?.reportInternalError(AnalyticsError.storageUnableToRename(file.path))
        }
        
        // necessary for testing, do not use.
        onFinish?(tempFile)

        let currentFile: Int = (userDefaults?.integer(forKey: Constants.events.rawValue) ?? 0) + 1
        userDefaults?.set(currentFile, forKey: Constants.events.rawValue)
    }
}
