//
//  State.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran

// MARK: - System (Overall)

struct System: State {
    let configuration: Configuration
    let settings: Settings?
    let running: Bool
    let enabled: Bool
    
    struct UpdateSettingsAction: Action {
        let settings: Settings
        
        func reduce(state: System) -> System {
            let result = System(configuration: state.configuration,
                                settings: settings,
                                running: state.running,
                                enabled: state.enabled)
            return result
        }
    }
        
    struct ToggleRunningAction: Action {
        let running: Bool
        
        func reduce(state: System) -> System {
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: running,
                          enabled: state.enabled)
        }
    }
    
    struct ToggleEnabledAction: Action {
        let enabled: Bool
        
        func reduce(state: System) -> System {
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: state.running,
                          enabled: enabled)
        }
    }
    
    struct UpdateConfigurationAction: Action {
        let configuration: Configuration
        
        func reduce(state: System) -> System {
            return System(configuration: configuration,
                          settings: state.settings,
                          running: state.running,
                          enabled: state.enabled)
        }
    }
    
    struct AddDestinationToSettingsAction: Action {
        let key: String
        
        func reduce(state: System) -> System {
            var settings = state.settings
            if var integrations = settings?.integrations?.dictionaryValue {
                integrations[key] = true
                settings?.integrations = try? JSON(integrations)
            }
            return System(configuration: state.configuration,
                          settings: settings,
                          running: state.running,
                          enabled: state.enabled)
        }
    }
}


// MARK: - User information

struct UserInfo: Codable, State {
    let anonymousId: String
    let userId: String?
    let traits: JSON?
    
    struct ResetAction: Action {
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: UUID().uuidString, userId: nil, traits: nil)
        }
    }
    
    struct SetUserIdAction: Action {
        let userId: String
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: state.anonymousId, userId: userId, traits: state.traits)
        }
    }
    
    struct SetTraitsAction: Action {
        let traits: JSON?
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: state.anonymousId, userId: state.userId, traits: traits)
        }
    }
    
    struct SetUserIdAndTraitsAction: Action {
        let userId: String
        let traits: JSON?
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: state.anonymousId, userId: userId, traits: traits)
        }
    }
    
    struct SetAnonymousIdAction: Action {
        let anonymousId: String
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: anonymousId, userId: state.userId, traits: state.traits)
        }
    }
}

// MARK: - Default State Setup

extension System {
    static func defaultState(configuration: Configuration, from storage: Storage) -> System {
        var settings: Settings? = storage.read(.settings)
        if settings == nil {
            if let defaults = configuration.values.defaultSettings {
                settings = defaults
            } else {
                settings = Settings(writeKey: configuration.values.writeKey, apiHost: HTTPClient.getDefaultAPIHost())
            }
        }
        return System(configuration: configuration, settings: settings, running: false, enabled: true)
    }
}

extension UserInfo {
    static func defaultState(from storage: Storage) -> UserInfo {
        let userId: String? = storage.read(.userId)
        let traits: JSON? = storage.read(.traits)
        var anonymousId: String = UUID().uuidString
        if let existingId: String = storage.read(.anonymousId) {
            anonymousId = existingId
        }
        return UserInfo(anonymousId: anonymousId, userId: userId, traits: traits)
    }
}
