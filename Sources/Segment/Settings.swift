//
//  Settings.swift
//  Segment
//
//  Created by Cody Garvin on 12/15/20.
//

import Foundation

public struct Settings: Codable {
    public var integrations: JSON? = nil
    public var plan: JSON? = nil
    public var edgeFunctions: JSON? = nil
    
    public init(writeKey: String, apiHost: String) {
        integrations = try! JSON([
            "Segment.io": [
                "apiKey": writeKey,
                "apiHost": apiHost
            ]
        ])
    }
    
    public init(from decoder: Decoder) throws {
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
    
    /**
     * Easily retrieve settings for a specific integration name.
     *
     * - Parameter for: The string name of the integration
     * - Returns: The dictionary representing the settings for this integration as supplied by Segment.com
     */
    public func integrationSettings(for name: String) -> [String: Any]? {
        guard let settings = integrations?.dictionaryValue else { return nil }
        let result = settings[name] as? [String: Any]
        return result
    }
}

extension Analytics {
    func checkSettings() {
        let writeKey = self.configuration.values.writeKey
        let httpClient = HTTPClient(analytics: self)
        httpClient.settingsFor(writeKey: writeKey) { (success, settings) in
            if success {
                if let s = settings {
                    // put the new settings in the state store.
                    // this will cause them to be cached.
                    self.store.dispatch(action: System.UpdateSettingsAction(settings: s))
                }
            }
        }
    }
}
