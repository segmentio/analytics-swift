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
    public var edgeFunction: JSON? = nil
    public var middlewareSettings: JSON? = nil

    public init(writeKey: String, apiHost: String) {
        integrations = try! JSON([
            SegmentDestination.Constants.integrationName.rawValue: [
                SegmentDestination.Constants.apiKey.rawValue: writeKey,
                SegmentDestination.Constants.apiHost.rawValue: apiHost
            ]
        ])
    }
    
    public init(writeKey: String) {
        integrations = try! JSON([
            SegmentDestination.Constants.integrationName.rawValue: [
                SegmentDestination.Constants.apiKey.rawValue: writeKey,
                SegmentDestination.Constants.apiHost.rawValue: HTTPClient.getDefaultAPIHost()
            ]
        ])
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.integrations = try? values.decode(JSON.self, forKey: CodingKeys.integrations)
        self.plan = try? values.decode(JSON.self, forKey: CodingKeys.plan)
        self.edgeFunction = try? values.decode(JSON.self, forKey: CodingKeys.edgeFunction)
        self.middlewareSettings = try? values.decode(JSON.self, forKey: CodingKeys.middlewareSettings)
    }
    
    static public func load(from url: URL?) -> Settings? {
        guard let url = url else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let settings = try? JSONDecoder().decode(Settings.self, from: data)
        return settings
    }
    
    static public func load(resource: String, bundle: Bundle = Bundle.main) -> Settings? {
        let url = bundle.url(forResource: resource, withExtension: nil)
        return load(from: url)
    }
    
    enum CodingKeys: String, CodingKey {
        case integrations
        case plan
        case edgeFunction
        case middlewareSettings
    }
    
    /**
     * Easily retrieve settings for a specific integration name.
     *
     * - Parameter for: The string name of the integration
     * - Returns: The dictionary representing the settings for this integration as supplied by Segment.com
     */
    public func integrationSettings(forKey key: String) -> [String: Any]? {
        guard let settings = integrations?.dictionaryValue else { return nil }
        let result = settings[key] as? [String: Any]
        return result
    }
    
    public func integrationSettings<T: Codable>(forKey key: String) -> T? {
        var result: T? = nil
        guard let settings = integrations?.dictionaryValue else { return nil }
        if let dict = settings[key], let jsonData = try? JSONSerialization.data(withJSONObject: dict) {
            result = try? JSONDecoder().decode(T.self, from: jsonData)
        }
        return result
    }
    
    public func integrationSettings<T: Codable>(forPlugin plugin: DestinationPlugin) -> T? {
        return integrationSettings(forKey: plugin.key)
    }
    
    public func hasIntegrationSettings(forPlugin plugin: DestinationPlugin) -> Bool {
        return hasIntegrationSettings(key: plugin.key)
    }

    public func hasIntegrationSettings(key: String) -> Bool {
        guard let settings = integrations?.dictionaryValue else { return false }
        return (settings[key] != nil)
    }
}

extension Settings: Equatable {
    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        let l = lhs.prettyPrint()
        let r = rhs.prettyPrint()
        return l == r
    }
}

extension Analytics {     
    internal func update(settings: Settings, type: UpdateType) {
        apply { (plugin) in
            // tell all top level plugins to update.
            update(plugin: plugin, settings: settings, type: type)
        }
    }
    
    internal func update(plugin: Plugin, settings: Settings, type: UpdateType) {
        plugin.update(settings: settings, type: type)
        // if it's a destination, tell it's plugins to update as well.
        if let dest = plugin as? DestinationPlugin {
            dest.apply { (subPlugin) in
                subPlugin.update(settings: settings, type: type)
            }
        }
    }
    
    internal func checkSettings() {
        #if DEBUG
        if isUnitTesting {
            // we don't really wanna wait for this network call during tests...
            // but we should make it work similarly.
            store.dispatch(action: System.ToggleRunningAction(running: false))
            DispatchQueue.main.async {
                if let state: System = self.store.currentState(), let settings = state.settings {
                    self.store.dispatch(action: System.UpdateSettingsAction(settings: settings))
                }
                self.store.dispatch(action: System.ToggleRunningAction(running: true))
            }
            return
        }
        #endif
        
        let writeKey = self.configuration.values.writeKey
        let httpClient = HTTPClient(analytics: self)
        let systemState: System? = store.currentState()
        let hasSettings = (systemState?.settings?.integrations != nil && systemState?.settings?.plan != nil)
        let updateType = (hasSettings ? UpdateType.refresh : UpdateType.initial)
        
        // stop things; queue in case our settings have changed.
        store.dispatch(action: System.ToggleRunningAction(running: false))
        httpClient.settingsFor(writeKey: writeKey) { (success, settings) in
            if success {
                if let s = settings {
                    // put the new settings in the state store.
                    // this will cause them to be cached.
                    self.store.dispatch(action: System.UpdateSettingsAction(settings: s))
                    // let plugins know we just received some settings..
                    self.update(settings: s, type: updateType)
                }
            }
            // we're good to go back to a running state.
            self.store.dispatch(action: System.ToggleRunningAction(running: true))
        }
    }
}
