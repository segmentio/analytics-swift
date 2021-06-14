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
    let integrations: JSON?
    let settings: Settings?
    let running: Bool
    
    struct UpdateSettingsAction: Action {
        let settings: Settings
        
        func reduce(state: System) -> System {
            let result = System(configuration: state.configuration,
                                integrations: state.integrations,
                                settings: settings,
                                running: state.running)
            return result
        }
    }
    
    struct AddIntegrationAction: Action {
        let pluginName: String
        
        func reduce(state: System) -> System {
            // we need to set any destination plugins to false in the
            // integrations payload.  this prevents them from being sent
            // by segment.com once an event reaches segment.
            if var integrations = state.integrations?.dictionaryValue {
                integrations[pluginName] = false
                if let jsonIntegrations = try? JSON(integrations) {
                    let result = System(configuration: state.configuration,
                                        integrations: jsonIntegrations,
                                        settings: state.settings,
                                        running: state.running)
                    return result
                }
            }
            return state
        }
    }
    
    struct RemoveIntegrationAction: Action {
        let pluginName: String
        
        func reduce(state: System) -> System {
            if var integrations = state.integrations?.dictionaryValue {
                integrations.removeValue(forKey: pluginName)
                if let jsonIntegrations = try? JSON(integrations) {
                    let result = System(configuration: state.configuration,
                                        integrations: jsonIntegrations,
                                        settings: state.settings,
                                        running: state.running)
                    return result
                }
            }
            return state
        }
    }
    
    struct ToggleRunningAction: Action {
        let running: Bool
        
        func reduce(state: System) -> System {
            return System(configuration: state.configuration,
                          integrations: state.integrations,
                          settings: state.settings,
                          running: running)
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
        let integrationDictionary = try! JSON([String: Any]())
        return System(configuration: configuration, integrations: integrationDictionary, settings: settings, running: false)
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
