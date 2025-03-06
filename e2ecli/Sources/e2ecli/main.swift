#!/usr/bin/env swift
//
// main.swift
//
// A command‐line tool to test Segment Analytics‑Swift SDK actions from a JSON file.
//

import Foundation
import Segment

var writeKey: String = ""
var apiHost: String = ""
var analytics: Analytics? = nil

// MARK: - Action Handlers

func processConfigure(_ action: [String: Any]) {
    print("writeKey: \(writeKey)")
    print("apihost: \(apiHost)")
    let config = Configuration(writeKey: writeKey)
    var waitUntilStarted = true

    // Set apiHost from command line argument or environment variable. May be overridden by test.
    if !apiHost.isEmpty {
        config.apiHost(apiHost)
    }

    for option in action {
        switch option.key {
        case "action", "writekey":
            // Ignore, already handled.
            continue
        case "flushAt":
            if let flushAt = option.value as? Int {
                config.flushAt(flushAt)
            }
        case "flushInterval":
            if let flushInterval = option.value as? TimeInterval {
                config.flushInterval(flushInterval)
            }
        case "trackApplicationLifecycleEvents":
            if let flag = option.value as? Bool {
                config.trackApplicationLifecycleEvents(flag)
            }
        case "autoAddSegmentDestination":
            if let flag = option.value as? Bool {
                config.autoAddSegmentDestination(flag)
            }
        case "apiHost":
            if let apiHost = option.value as? String {
                config.apiHost(apiHost)
            }
        case "cdnHost":
            if let cdnHost = option.value as? String {
                config.cdnHost(cdnHost)
            }
        case "operatingMode":
            if let modeString = option.value as? String {
                if modeString.lowercased() == "synchronous" {
                    config.operatingMode(.synchronous)
                } else {
                    config.operatingMode(.asynchronous)
                }
            }
        case "userAgent":
            if let userAgent = option.value as? String {
                config.userAgent(userAgent)
            }
        case "jsonNonConformingNumberStrategy":
            if let strategy = option.value as? String {
                switch strategy.lowercased() {
                case "zero":
                    config.jsonNonConformingNumberStrategy(.zero)
                case "throw":
                    config.jsonNonConformingNumberStrategy(.throw)
                case "null":
                    config.jsonNonConformingNumberStrategy(.null)
                default:
                    print("Unsupported jsonNonConformingNumberStrategy: \(strategy)")
                }
            }
        case "storageMode":
            if let modeValue = option.value as? String {
                switch modeValue.lowercased() {
                case "disk":
                    config.storageMode(.disk)
                default:
                    print("Unsupported storageMode string value: \(modeValue)")
                }
            } else if let memoryCount = option.value as? Int {
                config.storageMode(.memory(memoryCount))
            }
        case "waitUntilStarted":
            // Not a config option but a behavior modification - default true, can set false for specific tests
            if let wait = option.value as? Bool {
                waitUntilStarted = wait
            }
        default:
            print("Unknown option: \(option.key)")
        }
    }

    analytics = Analytics(configuration: config)
    
    var messageIds = [String]()
    analytics?.add { event in
        if let eventMessageId = event?.messageId {
            messageIds.append(eventMessageId)
        }
        return event
    }
    
    if waitUntilStarted {
        analytics?.waitUntilStarted()
    }
    if let analytics = analytics {
        print("Configured analytics: \(analytics)")
    } else {
        print("Failed to configure analytics.")
    }
}

// Process an 'identify' action.
func processIdentify(_ action: [String: Any]) {
    guard let userId = action["userId"] as? String else {
        print("Missing userId in identify action.")
        return
    }
    // Optional traits dictionary.
    let traits = action["traits"] as? [String: Any]
    print("Identifying userId: \(userId)")
    analytics?.identify(userId: userId, traits: traits)
}

// Process a 'track' action.
func processTrack(_ action: [String: Any]) {
    guard let event = action["event"] as? String else {
        print("Missing event in track action.")
        return
    }
    let properties = action["properties"] as? [String: Any]
    print("Tracking event: \(event)")
    analytics?.track(name: event, properties: properties)
}

// Process a 'screen' action.
func processScreen(_ action: [String: Any]) {
    guard let name = action["name"] as? String else {
        print("Missing name in screen action.")
        return
    }
    let category = action["category"] as? String
    let properties = action["properties"] as? [String: Any]
    print("Screening with name: \(name)")
    analytics?.screen(title: name, category: category, properties: properties)
}

func processGroup(_ action: [String: Any]) {
    guard let groupId = action["groupId"] as? String else {
        print("Missing groupId in group action.")
        return
    }
    print("Grouping with groupId: \(groupId)")
    analytics?.group(groupId: groupId)
}

func processAlias(_ action: [String: Any]) {
    guard let alias = action["newId"] as? String else {
        print("Missing newId in alias action.")
        return
    }
    print("Alias to newId: \(alias)")
    analytics?.alias(newId: alias)
}   

func processFlush(_ action: [String: Any]) {
    if let wait = action["wait"] as? Bool, wait {
        let semaphore = DispatchSemaphore(value: 0)
        analytics?.flush {
            semaphore.signal()
        }
        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("Flush timed out.")
        }
        print("Flush completed.")
    } else {
        analytics?.flush {
            print("Flush completed.")
        }
        print("Flush scheduled.")
    }
}

func processEnabled(_ action: [String: Any]) {
    guard let enabled = action["enabled"] as? Bool else {
        print("Missing enabled in enabled action.")
        return
    }
    print("Setting enabled to: \(enabled)")
    analytics?.enabled = enabled
}

func processWait(_ action: [String: Any]) {
    guard let seconds = action["seconds"] as? Int else {
        print("Missing seconds in wait action.")
        return
    }
    print("Waiting for \(seconds) seconds.")
    sleep(UInt32(seconds))
}

// Process one generic action according to its type.
func processAction(_ action: [String: Any]) {
    guard let actionType = action["action"] as? String else {
        if let comment = action["comment"] as? String {
            print("Comment: \(comment)")
        } else {
            print("Missing action type in action: \(action)")
        }
        return
    }

    switch actionType.lowercased() {
    case "configure":
        processConfigure(action)
    case "identify":
        processIdentify(action)
    case "track":
        processTrack(action)
    case "screen", "page":
        processScreen(action)
    case "group":
        processGroup(action)
    case "alias":
        processAlias(action)
    case "flush":
        processFlush(action)
    case "enabled":
        processEnabled(action)
    case "reset":
        analytics?.reset()
    case "purgeStorage":
        analytics?.purgeStorage()
    case "waitUntilStarted": // Only useful if `waitUntilStarted` is set to false in the configuration.
        analytics?.waitUntilStarted()
    case "wait":
        processWait(action)
    default:
        print("Unknown action: \(actionType)")
    }
}

// MARK: - Main Program
Telemetry.shared.enable = false
Analytics.debugLogsEnabled = true

// Ensure the JSON filename is passed as a command line argument.
guard CommandLine.arguments.count >= 2 else {
    print("Usage: \(CommandLine.arguments[0]) path/to/actions.json [-wWRITEKEY] [-aAPIHOST]")
    exit(1)
}

// Get the JSON file path from the command line arguments.
let jsonFilePath = CommandLine.arguments[1]
let fileUrl = URL(fileURLWithPath: jsonFilePath)

// Get the writeKey and apiHost from the command line arguments or environment variable.
writeKey = ""
apiHost = ""
for argument in CommandLine.arguments {
    if argument.hasPrefix("-w") {
        writeKey = String(argument.dropFirst(2))
    } else if argument.hasPrefix("-a") {
        apiHost = String(argument.dropFirst(2))
    }
}

// Get the writeKey and apiHost from environment variables if not provided as command line arguments.
if writeKey.isEmpty, let envWriteKey = ProcessInfo.processInfo.environment["E2E_WRITEKEY"] {
    writeKey = envWriteKey
}

if apiHost.isEmpty, let envApiHost = ProcessInfo.processInfo.environment["E2E_APIHOST"] {
    apiHost = envApiHost
}

if writeKey.isEmpty {
    print("Missing writeKey. Provide it as a command line argument with -wWRITEKEY or set the E2E_WRITEKEY environment variable.")
    exit(1)
}

do {
    let jsonData = try Data(contentsOf: fileUrl)
    // Expecting the JSON file to contain an array of actions:
    // [
    //   { "action": "identify", "userId": "user123", "traits": {"email": "test@example.com"} },
    //   { "action": "track", "event": "Item Purchased", "properties": {"item": "book", "price": 10} },
    //   { "action": "screen", "name": "Home", "category": "Landing", "properties": {"title": "Welcome"} },
    //   { "action": "group", "groupId": "group123" }
    // ]
    guard
        let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: [])
            as? [[String: Any]]
    else {
        print("JSON file does not contain an array of actions")
        exit(1)
    }

    // Process each action in the order received.
    for action in jsonArray {
        processAction(action)
        // Optionally flush after each action if needed:
        // Analytics.sharedInstance.flush()
    }

} catch {
    print("Error reading or parsing the JSON file: \(error)")
    exit(1)
}

print("All actions processed.")
// End of main.swift
