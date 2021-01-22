//
//  SegmentSwiftMixPanelPlugin.swift
//  SegmentExample
//
//  Created by Cody Garvin on 1/15/21.
//

import Segment
import Mixpanel

class SegmentMixPanel: DestinationPlugin {
    
    var type: PluginType
    var name: String
    var analytics: Analytics
    var timeline: Timeline
    private var mixpanel: Mixpanel? = nil
    private var settings: [String: JSON]? = nil
    
    required init(name: String, analytics: Analytics) {
        self.analytics = analytics
        self.name = name
        type = .destination
        self.timeline = Timeline()
    }
    
    func update(settings: Settings) {
        
        // If we have a mixpanel instance, dump all the data first
        mixpanel?.flush()
        
        // TODO: Update the proper types
        if let mixPanelSettings = settings.integrationSettings(for: "Mixpanel"),
           let token = mixPanelSettings["token"]?.stringValue {
            self.settings = mixPanelSettings
            mixpanel = Mixpanel.sharedInstance(withToken: token)
            
            // Check for EU endpoint
            if let euEndPointEnabled = self.settings?["enableEuropeanUnionEndpoint"]?.boolValue {
                if euEndPointEnabled {
                    mixpanel?.serverURL = "api-eu.mixpanel.com"
                }
            }
        } else {
            mixpanel = nil
            analytics.log(message: "Could not load Mixpanel settings")
        }
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        
        // Ensure that the userID is set and valid
        if let eventUserID = event.userId, !eventUserID.isEmpty {
            mixpanel?.identify(eventUserID)
            analytics.log(message: "Mixpanel identify \(eventUserID)")
        }
        
        let keyMap = ["$first_name": "firstName",
                      "$last_name": "lastName",
                      "$created": "createdAt",
                      "$last_seen": "lastSeen",
                      "$email": "email",
                      "$name": "name",
                      "$username": "username",
                      "$phone": "phone"]
        
        guard let traits = event.traits?.dictionaryValue2 else {
            return event
        }
        
        if setAllTraitsByDefault() {
            let mappedTraits = mapTraits(traits, keyMap: keyMap)
            
            // Register the mapped traits
            mixpanel?.registerSuperProperties(mappedTraits)
            analytics.log(message: "Mixpanel registerSuperProperties \(mappedTraits)")
            
            // Mixpanel also has a people API that works separately so we set hte traits for it as well.
            if peopleEnabled() {
                mixpanel?.people.set(mappedTraits)
                analytics.log(message: "Mixpanel people set \(mappedTraits)")
            }
        }
        
        if let superProperties = settings?["superProperties"]?.arrayValue {
            var superPropertyTraits = [AnyHashable: Any]()
            for superPropertyJSON in superProperties {
                if let superProperty = superPropertyJSON.stringValue {
                    superPropertyTraits[superProperty] = traits[superProperty]
                }
            }
            let mappedSuperProperties = mapTraits(superPropertyTraits, keyMap: keyMap)
            mixpanel?.registerSuperProperties(mappedSuperProperties)
            analytics.log(message: "Mixpanel registerSuperProperties \(mappedSuperProperties)")
            
            if peopleEnabled(), let peopleProperties = settings?["peopleProperties"]?.arrayValue {
                var peoplePropertyTraits = [AnyHashable: Any]()
                for peoplePropertyJSON in peopleProperties {
                    if let peopleProperty = peoplePropertyJSON.stringValue {
                        peoplePropertyTraits[peopleProperty] = traits[peopleProperty]
                    }
                }
                let mappedPeopleProperties = mapTraits(peoplePropertyTraits, keyMap: keyMap)
                mixpanel?.people.set(mappedPeopleProperties)
                analytics.log(message: "Mixpanel people set \(mappedSuperProperties)")
            }
        }
        
        return event
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
        if let eventName = event.event {
            mixpanelTrack(eventName, properties: event.properties?.dictionaryValue2)
        }
        return event
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        if settings?["consolidatedPageCalls"]?.boolValue ?? false,
           var payloadProps = event.properties?.dictionaryValue2 {
            
            let eventName = "Loaded a Screen"
            if let name = event.name {
                payloadProps["name"] = name
            }
            mixpanelTrack(eventName, properties: payloadProps)
            analytics.log(message: "Mixpanel track \(eventName) properties \(payloadProps)")
        } else if settings?["trackAllPages"]?.boolValue ?? false {
            
            var finalEventName = "Viewed Screen"
            if let eventName = event.name {
                finalEventName = "Viewed \(eventName) Screen"
            }
            
            mixpanelTrack(finalEventName, properties: event.properties?.dictionaryValue2)
            analytics.log(message: "Mixpanel track \(finalEventName) properties \(String(describing: event.properties?.dictionaryValue2))")
        } else if settings?["trackNamedPages"]?.boolValue ?? false, let eventName = event.name {
            let finalEventName = "Viewed \(eventName) Screen"
            mixpanelTrack(finalEventName, properties: event.properties?.dictionaryValue2)
            analytics.log(message: "Mixpanel track \(finalEventName) properties \(String(describing: event.properties?.dictionaryValue2))")
        } else if settings?["trackCategorizedPages"]?.boolValue ?? false, let category = event.category {
            let finalEventName = "Viewed \(category) Screen"
            mixpanelTrack(finalEventName, properties: event.properties?.dictionaryValue2)
            analytics.log(message: "Mixpanel track \(finalEventName) properties \(String(describing: event.properties?.dictionaryValue2))")
        }
        
        return event
    }
    
    func group(event: GroupEvent) -> GroupEvent? {
        
        guard let groupID = event.groupId, !groupID.isEmpty,
              let groupIdentifierProperties = settings?["groupIdentifierTraits"]?.arrayValue else {
            return event
        }
        
        // No need to continue if we don't have any properties
        if groupIdentifierProperties.isEmpty {
            return event
        }
        
        for key in groupIdentifierProperties {
            let nsGroupID = NSString(string: groupID)

            guard let key = key.stringValue else { continue }
            
            if let traits = event.traits?.dictionaryValue2 {
                if let group = traits[key] as? String {
                    mixpanel?.getGroup(group, groupID: nsGroupID).setOnce(traits)
                }
            }
            
            mixpanel?.setGroup(key, groupID: nsGroupID)
            analytics.log(message: "Mixpanel setGroup \(key) groupID \(groupID)")
        }
        
        return event
    }
    
    func alias(event: AliasEvent) -> AliasEvent? {
        // Use Mixpanel generated id
        if let distinctId = mixpanel?.distinctId, let newId = event.userId {
            mixpanel?.createAlias(newId, forDistinctID: distinctId)
        }
        return event
    }
    
    func registeredForRemoteNotificationsWithDeviceToken(_ deviceToken: Data) {
        mixpanel?.people.addPushDeviceToken(deviceToken)
        analytics.log(message: "Mixpanel people addPushDeviceToken \(deviceToken.toString())")
    }
    
    func reset() {
        flush()
        
        mixpanel?.reset()
        analytics.log(message: "Mixpanel reset")
    }
    
    func flush() {
        mixpanel?.flush()
        analytics.log(message: "Mixpanel Flush")
    }
    
    // MARK: - Private Methods
    private func mixpanelTrack(_ eventName: String, properties: [String: Any]? = nil) {
        // Track the raw event
        mixpanel?.track(eventName, properties: properties)
        
        // Don't send anything else to mixpanel if it is disabled
        if !peopleEnabled() {
            return
        }
        
        
        if let properties = properties {
            // Increment properties that are listed in the Mixpanel integration settings
            incrementProperties(properties)
            
            // Extract the revenue from the properties passed in to us
            if let revenue = extractRevenue(properties, key: "revenue") {
                mixpanel?.people.trackCharge(NSNumber(value: revenue))
                analytics.log(message: "Mixpanel people trackCharge \(revenue)")
            }
        }
        
        if eventShouldIncrement(event: eventName) {
            mixpanel?.people.increment(eventName, by: NSNumber(value: 1))
            analytics.log(message: "Mixpanel people increment \(eventName) by 1")
            
            let lastEvent = "Last \(eventName)"
            let lastDate = NSDate()
            mixpanel?.people.set(lastEvent, to: lastDate)
            analytics.log(message: "Mixpanel people set \(lastEvent) to \(lastDate)")
        }
        
    }
    
    private func extractRevenue(_ properties: [String: Any], key: String) -> Int? {
        var revenue: Int? = nil
        if let revenueProperty = properties[key] {
            if let revenueProperty = revenueProperty as? String {
                revenue = Int(revenueProperty)
            } else if let revenueProperty = revenueProperty as? NSNumber {
                revenue = revenueProperty.intValue
            }
        }
        
        return revenue
    }
    
    private func eventShouldIncrement(event: String) -> Bool {
        var shouldIncrement = false
        if let propertyIncrements = settings?["eventIncrements"]?.arrayValue {
            for increment in propertyIncrements {
                if let increment = increment.stringValue, event.lowercased() == increment.lowercased() {
                    shouldIncrement = true
                    break
                }
            }
        }
        
        return shouldIncrement
    }
    
    private func incrementProperties(_ properties: [String: Any]) {
        if let propertyIncrements = settings?["propIncrements"]?.arrayValue {
            for propIncrement in propertyIncrements {
                if let propString = propIncrement.stringValue {
                    for property in properties.keys {
                        if propString.lowercased() == property.lowercased(),
                           let incrementValue = properties[property] as? Int {
                            mixpanel?.people.increment(property, by: NSNumber(value: incrementValue))
                            analytics.log(message: "Mixpanel people increment \(property) by \(incrementValue)")
                        }
                    }
                }
            }
        }
    }
    
    private func peopleEnabled() -> Bool {
        var enabled = false
        if let peopleEnabled = settings?["people"]?.boolValue {
            enabled = peopleEnabled
        }
        
        return enabled
    }
    
    private func setAllTraitsByDefault() -> Bool {
        var traitsByDefault = false
        if let setAllTraitsByDefault = settings?["setAllTraitsByDefault"]?.boolValue {
            traitsByDefault = setAllTraitsByDefault
        }
        
        return traitsByDefault
    }
    
    private func mapTraits(_ traits: [AnyHashable: Any], keyMap: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var returnMap = traits
        for (key, value) in traits {
            if keyMap.keys.contains(key), let newKey = keyMap[key] as? String {
                returnMap.removeValue(forKey: key)
                returnMap[newKey] = value
            }
        }
        return returnMap
    }
}
