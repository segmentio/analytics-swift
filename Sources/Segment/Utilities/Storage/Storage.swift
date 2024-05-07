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
    let userDefaults: UserDefaults
    static let MAXFILESIZE = 475000 // Server accepts max 500k per batch

    internal var onFinish: ((URL) -> Void)? = nil
    internal weak var analytics: Analytics? = nil
    
    internal let dataStore: TransientDB
    internal let storageMode: StorageMode
    
    init(store: Store, writeKey: String, storageMode: StorageMode, operatingMode: OperatingMode) {
        self.writeKey = writeKey
        self.storageMode = storageMode
        self.userDefaults = UserDefaults(suiteName: "com.segment.storage.\(writeKey)")!
        
        var storageURL = CioAnalytics.eventStorageDirectory(writeKey: writeKey)
        let asyncAppend = (operatingMode == .asynchronous)
        switch storageMode {
        case .diskAtURL(let url):
            storageURL = url
            fallthrough
        case .disk:
            let store = DirectoryStore(
                configuration: DirectoryStore.Configuration(
                    writeKey: writeKey,
                    storageLocation: storageURL,
                    baseFilename: "segment-events",
                    maxFileSize: Self.MAXFILESIZE,
                    indexKey: Storage.Constants.events.rawValue))
            self.dataStore = TransientDB(store: store, asyncAppend: asyncAppend)
        case .memory(let max):
            let store = MemoryStore(
                configuration: MemoryStore.Configuration(
                    writeKey: writeKey,
                    maxItems: max,
                    maxFetchSize: Self.MAXFILESIZE))
            self.dataStore = TransientDB(store: store, asyncAppend: asyncAppend)
        case .custom(let store):
            self.dataStore = TransientDB(store: store, asyncAppend: asyncAppend)
        }
        
        store.subscribe(self) { [weak self] (state: UserInfo) in
            self?.userInfoUpdate(state: state)
        }
        store.subscribe(self) { [weak self] (state: System) in
            self?.systemUpdate(state: state)
        }
    }
    
    func write<T: Codable>(_ key: Storage.Constants, value: T?) {
        switch key {
        case .events:
            if let event = value as? RawEvent {
                dataStore.append(data: event)
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
                userDefaults.set(value, forKey: key.rawValue)
            } else {
                // encode it to a data object to store
                let encoder = PropertyListEncoder()
                if let plistValue = try? encoder.encode(value) {
                    userDefaults.set(plistValue, forKey: key.rawValue)
                }
            }
            userDefaults.synchronize()
        }
    }
    
    func read(_ key: Storage.Constants) -> DataResult? {
        switch key {
        case .events:
            return dataStore.fetch()
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
            let raw = userDefaults.object(forKey: key.rawValue)
            if let r = raw as? Data {
                // it's an encoded object, not a basic type
                result = try? decoder.decode(T.self, from: r)
            } else {
                // it's a basic type
                result = userDefaults.object(forKey: key.rawValue) as? T
            }
        }
        return result
    }
    
    static func hardSettingsReset(writeKey: String) {
        guard let defaults = UserDefaults(suiteName: "com.segment.storage.\(writeKey)") else { return }
        for key in Constants.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
    
    func hardReset(doYouKnowHowToUseThis: Bool) {
        if doYouKnowHowToUseThis != true { return }
        dataStore.reset()
        guard let defaults = UserDefaults(suiteName: "com.segment.storage.\(writeKey)") else { return }
        for key in Constants.allCases {
            defaults.removeObject(forKey: key.rawValue)
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
    
    func remove(data: [DataStore.ItemID]?) {
        guard let data else { return }
        dataStore.remove(data: data)
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
