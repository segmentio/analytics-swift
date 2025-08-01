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
    let initializedPlugins: [Plugin]
    let waitingPlugins: [Plugin]
    
    struct UpdateSettingsAction: Action {
        let settings: Settings
        
        func reduce(state: System) -> System {
            let result = System(configuration: state.configuration,
                                settings: settings,
                                running: state.running,
                                enabled: state.enabled,
                                initializedPlugins: state.initializedPlugins,
                                waitingPlugins: state.waitingPlugins)
            return result
        }
    }
        
    struct ToggleRunningAction: Action {
        let running: Bool
        
        func reduce(state: System) -> System {
            var desiredRunning = running
            
            if desiredRunning == true && state.waitingPlugins.count > 0 {
                desiredRunning = false
            }
            
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: desiredRunning,
                          enabled: state.enabled,
                          initializedPlugins: state.initializedPlugins,
                          waitingPlugins: state.waitingPlugins)
        }
    }
    
    struct ForceRunningAction: Action {
        func reduce(state: System) -> System {
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: true,
                          enabled: state.enabled,
                          initializedPlugins: state.initializedPlugins,
                          waitingPlugins: state.waitingPlugins)
        }
    }
    
    struct ToggleEnabledAction: Action {
        let enabled: Bool
        
        func reduce(state: System) -> System {
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: state.running,
                          enabled: enabled,
                          initializedPlugins: state.initializedPlugins,
                          waitingPlugins: state.waitingPlugins)
        }
    }
    
    struct UpdateConfigurationAction: Action {
        let configuration: Configuration
        
        func reduce(state: System) -> System {
            return System(configuration: configuration,
                          settings: state.settings,
                          running: state.running,
                          enabled: state.enabled,
                          initializedPlugins: state.initializedPlugins,
                          waitingPlugins: state.waitingPlugins)
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
                          enabled: state.enabled,
                          initializedPlugins: state.initializedPlugins,
                          waitingPlugins: state.waitingPlugins)
        }
    }
    
    struct AddPluginToInitialized: Action {
        let plugin: Plugin
        
        func reduce(state: System) -> System {
            var initializedPlugins = state.initializedPlugins
            if !initializedPlugins.contains(where: { p in
                return plugin === p
            }) {
                initializedPlugins.append(plugin)
            }
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: state.running,
                          enabled: state.enabled,
                          initializedPlugins: initializedPlugins,
                          waitingPlugins: state.waitingPlugins)
        }
    }
    
    struct AddWaitingPlugin: Action {
        let plugin: Plugin
        
        func reduce(state: System) -> System {
            var waitingPlugins = state.waitingPlugins
            if !waitingPlugins.contains(where: { p in
                return plugin === p
            }) {
                waitingPlugins.append(plugin)
            }
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: state.running,
                          enabled: state.enabled,
                          initializedPlugins: state.initializedPlugins,
                          waitingPlugins: waitingPlugins)
        }
    }
    
    struct RemoveWaitingPlugin: Action {
        let plugin: Plugin
        
        func reduce(state: System) -> System {
            var waitingPlugins = state.waitingPlugins
            waitingPlugins.removeAll { p in
                return plugin === p
            }
            
            return System(configuration: state.configuration,
                          settings: state.settings,
                          running: state.running,
                          enabled: state.enabled,
                          initializedPlugins: state.initializedPlugins,
                          waitingPlugins: waitingPlugins)
        }
    }
}


// MARK: - User information

struct UserInfo: Codable, State {
    let anonymousId: String
    let userId: String?
    let traits: JSON
    let referrer: URL?
    
    @Noncodable var anonIdGenerator: AnonymousIdGenerator?
    
    struct ResetAction: Action {
        func reduce(state: UserInfo) -> UserInfo {
            var anonId: String
            if let id = state.anonIdGenerator?.newAnonymousId() {
                anonId = id
            } else {
                anonId = UUID().uuidString
            }
            return UserInfo(anonymousId: anonId, userId: nil, traits: .object([:]), referrer: nil, anonIdGenerator: state.anonIdGenerator)
        }
    }
    
    struct SetUserIdAction: Action {
        let userId: String
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: state.anonymousId, userId: userId, traits: state.traits, referrer: state.referrer, anonIdGenerator: state.anonIdGenerator)
        }
    }
    
    struct SetTraitsAction: Action {
        let traits: JSON?
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: state.anonymousId, userId: state.userId, traits: traits ?? .object([:]), referrer: state.referrer, anonIdGenerator: state.anonIdGenerator)
        }
    }
    
    struct SetUserIdAndTraitsAction: Action {
        let userId: String?
        let traits: JSON?
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: state.anonymousId, userId: userId, traits: traits ?? .object([:]), referrer: state.referrer, anonIdGenerator: state.anonIdGenerator)
        }
    }
    
    struct SetReferrerAction: Action {
        let url: URL
        
        func reduce(state: UserInfo) -> UserInfo {
            return UserInfo(anonymousId: state.anonymousId, userId: state.userId, traits: state.traits, referrer: url, anonIdGenerator: state.anonIdGenerator)
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
        return System(
            configuration: configuration,
            settings: settings,
            running: false,
            enabled: true,
            initializedPlugins: [Plugin](),
            waitingPlugins: [WaitingPlugin]()
        )
    }
}

extension UserInfo {
    static func defaultState(from storage: Storage, anonIdGenerator: AnonymousIdGenerator) -> UserInfo {
        let userId: String? = storage.read(.userId)
        let traits: JSON = storage.read(.traits) ?? .object([:])
        var anonymousId: String
        if let existingId: String = storage.read(.anonymousId) {
            anonymousId = existingId
        } else {
            anonymousId = anonIdGenerator.newAnonymousId()
        }
        return UserInfo(anonymousId: anonymousId, userId: userId, traits: traits, referrer: nil, anonIdGenerator: anonIdGenerator)
    }
}
