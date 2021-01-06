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
            userDefaults?.setValue(value, forKey: key.rawValue)
        }
    }
    
    func read<T: Codable>(_ key: Storage.Contants) -> T? {
        var result: T? = nil
        switch key {
        case .events:
            break
        default:
            result = userDefaults?.object(forKey: key.rawValue) as? T
        }
        return result
    }
    
    func clear() {
        for key in Contants.allCases {
            userDefaults?.setValue(nil, forKey: key.rawValue)
        }
    }
}

// MARK: - Pull stored state

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
    }
}
