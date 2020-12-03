//
//  State.swift
//  Segment
//
//  Created by Brandon Sneed on 12/1/20.
//

import Foundation
import Sovran

// MARK: - State Types

struct System: Codable, State {
    let enabled: Bool
}

struct UserInfo: Codable, State {
    let anonymousId: String
    let userId: String?
    let traits: JSON?
}

