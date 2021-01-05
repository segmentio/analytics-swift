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
    let enabled: Bool
    let configuration: Configuration
    let context: JSON?
    let integrations: JSON?
    let settings: Settings?
    
    struct EnabledAction: Action {
        var enabled: Bool
        func reduce(state: System) -> System {
            let result = System(enabled: enabled,
                                configuration: state.configuration,
                                context: state.context,
                                integrations: state.integrations,
                                settings: state.settings)
            return result
        }
    }
    
    struct UpdateSettings: Action {
        let settings: Settings
        
        func reduce(state: System) -> System {
            let result = System(enabled: state.enabled,
                                configuration: state.configuration,
                                context: state.context,
                                integrations: state.integrations,
                                settings: settings)
            return result

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


