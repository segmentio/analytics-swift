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
    
    struct EnabledAction: Action {
        var enabled: Bool
        func reduce(state: System) -> System {
            let result = System(enabled: enabled,
                                configuration: state.configuration,
                                context: state.context,
                                integrations: state.integrations)
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
}


