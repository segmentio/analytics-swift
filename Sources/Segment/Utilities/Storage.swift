//
//  Storage.swift
//  Segment
//
//  Created by Brandon Sneed on 1/5/21.
//

import Foundation
import Sovran

internal class Storage: Subscriber {
    let userDefaults = UserDefaults(suiteName: "com.segment.storage")
    
    init(store: Store) {
        store.subscribe(self, handler: userInfoUpdate)
        store.subscribe(self, handler: systemUpdate)
    }
}

// MARK: - String Contants

extension Storage {
    enum Contants: String, CaseIterable {
        case username = "segment.username"
        case traits = "segment.traits"
        case anonymousId = "segment.anonymousId"
        case settings = "segment.settings"
        case events = "segment.events"
    }
}

// MARK: - Read/Write

extension Storage {
    func write<T: Codable>(_ key: Storage.Contants, value: T?) {
        switch key {
        case .events:
            break
        default:
            if isBasicType(value: value) {
                // we can write it like normal
                userDefaults?.setValue(value, forKey: key.rawValue)
            } else {
                // encode it to a data object to store
                let encoder = PropertyListEncoder()
                if let plistValue = try? encoder.encode(value) {
                    userDefaults?.setValue(plistValue, forKey: key.rawValue)
                }
            }
        }
    }
    
    func read<T: Codable>(_ key: Storage.Contants) -> T? {
        var result: T? = nil
        switch key {
        case .events:
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
    
    func reset() {
        for key in Contants.allCases {
            userDefaults?.setValue(nil, forKey: key.rawValue)
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
        write(.username, value: state.userId)
        write(.traits, value: state.traits)
        write(.anonymousId, value: state.anonymousId)
    }
    
    func systemUpdate(state: System) {
        // write new stuff to disk
        if let s = state.settings as? RawSettings {
            write(.settings, value: s)
        }
    }
}
