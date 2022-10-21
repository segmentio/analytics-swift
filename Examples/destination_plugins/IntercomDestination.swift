//
//  IntercomDestination.swift
//  IntercomDestination
//
//  Created by Cody Garvin on 9/21/21.
//

import Segment
import Intercom
import CoreMedia

/**
 An implementation of the Intercom Analytics device mode destination as a plugin.
 */

// NOTE: You can see this plugin in use in the DestinationsExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.
//
// Copyright (c) 2022 Segment
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

class IntercomDestination: DestinationPlugin {
    let timeline = Timeline()
    let type = PluginType.destination
    let key = "Intercom"
    weak var analytics: Analytics? = nil
    
    private var intercomSettings: IntercomSettings?
    private var configurationLabels = [String: Any]()
        
    func update(settings: Settings, type: UpdateType) {
        // Skip if you have a singleton and don't want to keep updating via settings.
        guard type == .initial else { return }
                
        // Grab the settings and assign them for potential later usage.
        // Note: Since integrationSettings is generic, strongly type the variable.
        guard let tempSettings: IntercomSettings = settings.integrationSettings(forPlugin: self) else { return }
        intercomSettings = tempSettings
        Intercom.setApiKey(tempSettings.mobileApiKey, forAppId: tempSettings.appId)
        analytics?.log(message: "Intercolm.setApiKey(\(tempSettings.mobileApiKey), forApId:\(tempSettings.appId))", kind: .debug)
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        
        if let userId = event.userId {
            Intercom.registerUser(withUserId: userId)
            analytics?.log(message: "Intercom.registerUser(withUserId: \(userId)", kind: .debug)
        } else if let _ = event.anonymousId {
            Intercom.registerUnidentifiedUser()
            analytics?.log(message: "Intercom.registerUnidentifiedUser()", kind: .debug)
        }
        
        if let integration = event.integrations?.dictionaryValue?["Intercom"] as? [AnyHashable: Any],
           let userHash = integration["user_hash"] as? String {
            Intercom.setUserHash(userHash)
        }
        
        if let traits = event.traits?.dictionaryValue {
            // Set user attributes
            setUserAttributes(traits, event: event)
        }
        
        return event
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
                
        // Properties can not be empty
        guard let properties = event.properties?.dictionaryValue else {
            
            Intercom.logEvent(withName: event.event)
            analytics?.log(message: "Intercom.logEvent(withName: \(event.event))", kind: .debug)
            return event
        }
        
        var output = [String: Any]()
        var price = [String: Any]()
        var isAmountSet = false
        
        for (key, value) in properties {
            output[key] = value
            
            if let dataValue = value as? Double,
                key == "revenue" || key == "total" && !isAmountSet {
                let amountInCents = dataValue * 100
                price["amount"] = amountInCents
                output.removeValue(forKey: key)
                isAmountSet = true
            }
            
            if key == "currency" {
                price["currency"] = value
                output.removeValue(forKey: "currency")
            }
            
            if price.count > 0 {
                output["price"] = price
            }
            
            if value is [String: Any] || value is [Any] {
                output.removeValue(forKey: key)
            }
        }
        
        Intercom.logEvent(withName: event.event, metaData: output)
        analytics?.log(message: "Intercom.logEvent(withName: \(event.event), metaData: \(output))", kind: .debug)
        
        return event
    }
    
    func group(event: GroupEvent) -> GroupEvent? {
        
        // id is required field for adding or modifying a company
        guard let traits = event.traits?.dictionaryValue,
                let groupId = event.groupId else { return event }
        
        let company = setCompanyAttributes(traits)
        company.companyId = groupId
        
        let userAttributes = ICMUserAttributes()
        userAttributes.companies = [company]
        
        Intercom.updateUser(userAttributes)
        analytics?.log(message: "Intercom.updateUser(\(userAttributes))", kind: .debug)
        
        return event
    }
    
    func reset() {
        Intercom.logout()
        analytics?.log(message: "Intercom.logout()", kind: .debug)
    }
}

// Example of what settings may look like.
private struct IntercomSettings: Codable {
    let appId: String
    let mobileApiKey: String
}

private extension IntercomDestination {
    
    func setUserAttributes(_ traits: [String: Any], event: RawEvent?) {
        let userAttributes = ICMUserAttributes()
        var customAttributes = traits
        
        if let email = traits["email"] as? String {
            userAttributes.email = email
            customAttributes.removeValue(forKey: "email")
        }
        
        if let userId = traits["user_id"] as? String {
            userAttributes.userId = userId
            customAttributes.removeValue(forKey: "user_id")
        }
        
        if let name = traits["name"] as? String {
            userAttributes.name = name
            customAttributes.removeValue(forKey: "name")
        }
        
        if let phone = traits["phone"] as? String {
            userAttributes.phone = phone
            customAttributes.removeValue(forKey: "phone")
        }
        
        if let createdAt = traits["created_at"] as? Double {
            let date = Date(timeIntervalSince1970: createdAt)
            userAttributes.signedUpAt = date
            customAttributes.removeValue(forKey: "created_at")
        }
        
        if let integration = event?.integrations?.dictionaryValue?["Intercom"] as? [AnyHashable: Any] {
            if let languageOverride = integration["language_override"] as? String {
                userAttributes.languageOverride = languageOverride
            }
            
            if let unsubscribed = integration["unsubscribed"] as? Bool {
                userAttributes.unsubscribedFromEmails = unsubscribed
            }
        }
        
        if let company = traits["company"] as? [String: Any] {
            let companyData = setCompanyAttributes(company)
            userAttributes.companies = [companyData]
        }
        
        for (key, value) in traits {
            if !(value is String) &&
                !(value is Int) &&
                !(value is Double) &&
                !(value is Bool) {
                customAttributes.removeValue(forKey: key)
            }
        }
        
        userAttributes.customAttributes = customAttributes
        Intercom.updateUser(userAttributes)
        analytics?.log(message: "Intercom.updateUser(\(userAttributes)", kind: .debug)
    }
    
    func setCompanyAttributes(_ company: [String: Any]) -> ICMCompany {
        let companyData = ICMCompany()
        var customTraits = company
        
        if let companyId = company["id"] as? String {
            companyData.companyId = companyId
            customTraits.removeValue(forKey: "id")
        }
        
        if let monthlySpending = company["monthly_spend"] as? Double {
            companyData.monthlySpend = NSNumber(value: monthlySpending)
            customTraits.removeValue(forKey: "monthly_spend")
        }
        
        if let plan = company["plan"] as? String {
            companyData.plan = plan
            customTraits.removeValue(forKey: "plan")
        }
        
        if let createdAt = company["created_at"] as? Double {
            let date = Date(timeIntervalSince1970: createdAt)
            companyData.createdAt = date
            customTraits.removeValue(forKey: "created_at")
        }

        for (key, value) in company {
            if !(value is String) &&
                !(value is Int) &&
                !(value is Double) &&
                !(value is Bool) {
                customTraits.removeValue(forKey: key)
            }
        }

        companyData.customAttributes = customTraits
        
        return companyData
    }
}
