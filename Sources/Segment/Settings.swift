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
    public var metrics: JSON? = nil
    public var consentSettings: JSON? = nil

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
        self.metrics = try? values.decode(JSON.self, forKey: CodingKeys.metrics)
        self.consentSettings = try? values.decode(JSON.self, forKey: CodingKeys.consentSettings)
    }
    
    static public func load(from url: URL?) -> Settings? {
        guard let url = url else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let settings = try? JSONDecoder.default.decode(Settings.self, from: data)
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
        case metrics
        case consentSettings
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
            result = try? JSONDecoder.default.decode(T.self, from: jsonData)
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
    internal func update(settings: Settings) {
        guard let system: System = store.currentState() else { return }
        apply { plugin in
            plugin.update(settings: settings, type: updateType(for: plugin, in: system))
            if let destPlugin = plugin as? DestinationPlugin {
                destPlugin.apply { subPlugin in
                    subPlugin.update(settings: settings, type: updateType(for: subPlugin, in: system))
                }
            }
        }
    }
    
    internal func updateIfNecessary(plugin: Plugin) {
        guard let system: System = store.currentState() else { return }
        // if we're already running, update has already been called for existing plugins,
        // so we just wanna call it on this one if it hasn't been done already.
        if system.running, let settings = system.settings {
            let alreadyInitialized = system.initializedPlugins.contains { p in
                return plugin === p
            }
            if !alreadyInitialized {
                store.dispatch(action: System.AddPluginToInitialized(plugin: plugin))
                plugin.update(settings: settings, type: .initial)
            } else {
                plugin.update(settings: settings, type: .refresh)
            }
        }
    }
    
    internal func updateType(for plugin: Plugin, in system: System) -> UpdateType {
        let alreadyInitialized = system.initializedPlugins.contains { p in
            return plugin === p
        }
        if alreadyInitialized {
            return .refresh
        } else {
            store.dispatch(action: System.AddPluginToInitialized(plugin: plugin))
            return .initial
        }
    }
    
    internal func checkSettings() {
        #if DEBUG
        if isUnitTesting {
            // we don't really wanna wait for this network call during tests...
            // but we should make it work similarly.
            store.dispatch(action: System.ToggleRunningAction(running: false))
            
            operatingMode.run(queue: DispatchQueue.main) {
                if let state: System = self.store.currentState(), let settings = state.settings {
                    self.store.dispatch(action: System.UpdateSettingsAction(settings: settings))
                    self.update(settings: settings)
                }
                self.store.dispatch(action: System.ToggleRunningAction(running: true))
            }
            
            return
        }
        #endif
        
        let writeKey = self.configuration.values.writeKey
        let httpClient = HTTPClient(analytics: self)
        
        // stop things; queue in case our settings have changed.
        store.dispatch(action: System.ToggleRunningAction(running: false))
        httpClient.settingsFor(writeKey: writeKey) { (success, settings) in
            if success {
                if let s = settings {
                    // put the new settings in the state store.
                    // this will cause them to be cached.
                    self.store.dispatch(action: System.UpdateSettingsAction(settings: s))
                    // let plugins know we just received some settings..
                    self.update(settings: s)
                }
            }
            // we're good to go back to a running state.
            self.store.dispatch(action: System.ToggleRunningAction(running: true))
        }
    }
}
