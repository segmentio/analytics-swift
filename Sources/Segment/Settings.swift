//
//  Settings.swift
//  Segment
//
//  Created by Cody Garvin on 12/15/20.
//

import Foundation

public protocol Settings: Codable {
    var integrations: JSON? { get set }
    var plan: JSON? { get set }
    var edgeFunctions: JSON? { get set }
}

struct RawSettings: Settings {
    var integrations: JSON?
    
    var plan: JSON?
    
    var edgeFunctions: JSON?
    
    init(writeKey: String, apiHost: String) {
        // TODO: HACK MONSTER
        integrations = try! JSON([
            "Segment.io": [
                "apiKey": writeKey,
                "apiHost": apiHost
            ]
        ])
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        integrations = try? values.decode(JSON.self, forKey: CodingKeys.integrations)
        self.plan = try? values.decode(JSON.self, forKey: CodingKeys.plan)
        self.edgeFunctions = try? values.decode(JSON.self, forKey: CodingKeys.edgeFunctions)
    }
    
    enum CodingKeys: String, CodingKey {
        case integrations
        case plan
        case edgeFunctions
    }
}

extension Analytics {
    func checkSettings() {
        let writeKey = self.configuration.writeKey
        let httpClient = HTTPClient(analytics: self)
        httpClient.settingsFor(writeKey: writeKey) { (success, settings) in
            if success {
                if let s = settings {
                    // put the new settings in the state store.
                    // this will cause them to be cached.
                    self.store.dispatch(action: System.UpdateSettingsAction(settings: s))
                }
            }
            
            // NOTE: cached and default settings are handled by the state object
            
            if let s = settings {
                print("Settings: \(s.prettyPrint())")
            }
        }
    }
}
