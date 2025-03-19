//
//  Analytics.swift
//  analytics-swift
//
//  Created by Brandon Sneed on 11/17/20.
//

import Foundation
import Sovran

// MARK: - Base Setup

public class Analytics {
    internal var configuration: Configuration {
        get {
            // we're absolutely certain we will have a config
            let system: System = store.currentState()!
            return system.configuration
        }
    }
    internal var store: Store
    internal var storage: Storage

    /// Enabled/disables debug logging to trace your data going through the SDK.
    public static var debugLogsEnabled = false

    public var timeline: Timeline

    static internal let deadInstance = "DEADINSTANCE"
    static internal weak var firstInstance: Analytics? = nil

    @Atomic static internal var activeWriteKeys = [String]()

    /**
     This method isn't a traditional singleton implementation.  It's provided here
     to ease migration from analytics-ios to analytics-swift.  Rather than return a
     singleton, it returns the first instance of Analytics created, OR an instance
     who's writekey is "DEADINSTANCE".

     In the case of a dead instance, an assert will be thrown when in DEBUG builds to
     assist developers in knowning that `shared()` is being called too soon.
     */
    public static func shared() -> Analytics {
        if let a = firstInstance {
            if a.isDead == false {
                return a
            }
        }

        #if DEBUG
        if isUnitTesting == false {
            assert(true == false, "An instance of Analytice does not exist!")
        }
        #endif

        return Analytics(configuration: Configuration(writeKey: deadInstance))
    }

    /// Initialize this instance of Analytics with a given configuration setup.
    /// - Parameters:
    ///    - configuration: The configuration to use
    public init(configuration: Configuration) {
        /*if Self.isActiveWriteKey(configuration.values.writeKey) {
            // If you're hitting this in testing, it could be a memory leak, or something async is still running
            // and holding a reference.  You can use XCTest.waitUntilFinished(...) to wait for things to complete.
            fatalError("Cannot initialize multiple instances of Analytics with the same write key")
        } else {
            Self.addActiveWriteKey(configuration.values.writeKey)
        }*/
        
        store = Store()
        storage = Storage(
            store: self.store,
            writeKey: configuration.values.writeKey,
            storageMode: configuration.values.storageMode,
            operatingMode: configuration.values.operatingMode
        )
        timeline = Timeline()

        // provide our default state
        store.provide(state: System.defaultState(configuration: configuration, from: storage))
        store.provide(state: UserInfo.defaultState(from: storage, anonIdGenerator: configuration.values.anonymousIdGenerator))
        
        storage.analytics = self

        checkSharedInstance()

        // Get everything running
        platformStartup()

        Telemetry.shared.increment(metric: Telemetry.INVOKE_METRIC) {it in 
            it["message"] = "configured"
            it["apihost"] = configuration.values.apiHost
            it["cdnhost"] = configuration.values.cdnHost
            it["flush"] =
                "at:\(configuration.values.flushAt) int:\(configuration.values.flushInterval) pol:\(configuration.values.flushPolicies.count)"
            it["config"] = "seg:\(configuration.values.autoAddSegmentDestination) ua:\(configuration.values.userAgent ?? "N/A")"
        }
    }
    
    deinit {
        Self.removeActiveWriteKey(configuration.values.writeKey)
    }

    internal func process<E: RawEvent>(incomingEvent: E, enrichments: [EnrichmentClosure]? = nil) {
        guard enabled == true else { return }
        let event = incomingEvent.applyRawEventData(store: store, enrichments: enrichments)

        _ = timeline.process(incomingEvent: event)

        /*let flushPolicies = configuration.values.flushPolicies
        for policy in flushPolicies {
            policy.updateState(event: event)

            if (policy.shouldFlush() == true) {
                flush()
                policy.reset()
            }
        }*/
        
        let flushPolicies = configuration.values.flushPolicies
        
        var shouldFlush = false
        // if any policy says to flush, make note of that
        for policy in flushPolicies {
            policy.updateState(event: event)
            if policy.shouldFlush() {
                shouldFlush = true
                // we don't need to updateState on any others since we're gonna reset it below.
                break
            }
        }
        // if we were told to flush do it.
        if shouldFlush {
            // reset all the policies if one decided to flush.
            flushPolicies.forEach {
                $0.reset()
            }
            flush()
        }
    }

    /// Process a raw event through the system.  Useful when one needs to queue and replay events at a later time.
    /// - Parameters:
    ///   - event: An event conforming to RawEvent that will be processed.
    public func process(event: RawEvent) {
        guard enabled == true else { return }
        switch event {
        case let e as TrackEvent:
            timeline.process(incomingEvent: e)
        case let e as IdentifyEvent:
            timeline.process(incomingEvent: e)
        case let e as ScreenEvent:
            timeline.process(incomingEvent: e)
        case let e as GroupEvent:
            timeline.process(incomingEvent: e)
        case let e as AliasEvent:
            timeline.process(incomingEvent: e)
        default:
            break
        }
    }
}

// MARK: - System Modifiers

extension Analytics {
    /// Enable/Disable analytics capture
    public var enabled: Bool {
        get {
            if let system: System = store.currentState() {
                return system.enabled
            }
            // we don't have state if we get here, so assume we're not enabled.
            return false
        }
        set(value) {
            store.dispatch(action: System.ToggleEnabledAction(enabled: value))
        }
    }
    
    /// Returns the writekey in use for this instance.
    public var writeKey: String {
        return configuration.values.writeKey
    }
    
    /// Returns the anonymousId currently in use.
    public var anonymousId: String {
        if let userInfo: UserInfo = store.currentState() {
            return userInfo.anonymousId
        }
        return ""
    }

    /// Returns the userId that was specified in the last identify call.
    public var userId: String? {
        if let userInfo: UserInfo = store.currentState() {
            return userInfo.userId
        }
        return nil
    }

    /// Returns the current operating mode this instance was given.
    public var operatingMode: OperatingMode {
        return configuration.values.operatingMode
    }

    /// Adjusts the flush interval post configuration.
    public var flushInterval: TimeInterval {
        get {
            configuration.values.flushInterval
        }
        set(value) {
            if let state: System = store.currentState() {
                let config = state.configuration.flushInterval(value)
                store.dispatch(action: System.UpdateConfigurationAction(configuration: config))
            }
        }
    }

    /// Adjusts the flush-at count post configuration.
    public var flushAt: Int {
        get {
            configuration.values.flushAt
        }
        set(value) {
            if let state: System = store.currentState() {
                let config = state.configuration.flushAt(value)
                store.dispatch(action: System.UpdateConfigurationAction(configuration: config))
            }
        }
    }

    /// Returns a list of currently active flush policies.
    public var flushPolicies: [FlushPolicy] {
        get {
            configuration.values.flushPolicies
        }
    }

    /// Returns the traits that were specified in the last identify call.
    public func traits<T: Codable>() -> T? {
        if let userInfo: UserInfo = store.currentState() {
            return userInfo.traits.codableValue()
        }
        return nil
    }

    /// Returns the traits that were specified in the last identify call, as a dictionary.
    public func traits() -> [String: Any]? {
        if let userInfo: UserInfo = store.currentState() {
            return userInfo.traits.dictionaryValue
        }
        return nil
    }

    /// Tells this instance of Analytics to flush any queued events up to Segment.com.  This command will also
    /// be sent to each plugin present in the system.  A completion handler can be optionally given and will be
    /// called when flush has completed.
    public func flush(completion: (() -> Void)? = nil) {
        // only flush if we're enabled.
        guard enabled == true else { completion?(); return }
        
        let completionGroup = CompletionGroup(queue: configuration.values.flushQueue)
        apply { plugin in
            completionGroup.add { group in
                if let p = plugin as? FlushCompletion {
                    p.flush(group: group)
                } else if let p = plugin as? EventPlugin {
                    group.enter()
                    p.flush()
                    group.leave()
                }
            }
        }
        
        completionGroup.run(mode: operatingMode) {
            completion?()
        }
    }

    /// Resets this instance of Analytics to a clean slate.  Traits, UserID's, anonymousId, etc are all cleared or reset.  This
    /// command will also be sent to each plugin present in the system.
    public func reset() {
        store.dispatch(action: UserInfo.ResetAction())
        apply { plugin in
            if let p = plugin as? EventPlugin {
                p.reset()
            }
        }
    }

    /// Retrieve the version of this library in use.
    /// - Returns: A string representing the version in "BREAKING.FEATURE.FIX" format.
    public func version() -> String {
        return Analytics.version()
    }

    /// Retrieve the version of this library in use.
    /// - Returns: A string representing the version in "BREAKING.FEATURE.FIX" format.
    public static func version() -> String {
        return __segment_version
    }
}

extension Analytics {
    /// Manually retrieve the settings that were supplied from Segment.com.
    /// - Returns: A Settings object containing integration settings, tracking plan, etc.
    public func settings() -> Settings? {
        var settings: Settings?
        if let system: System = store.currentState() {
            settings = system.settings
        }
        return settings
    }

    /// Manually enable a destination plugin.  This is useful when a given DestinationPlugin doesn't have any Segment tie-ins at all.
    /// This will allow the destination to be processed in the same way within this library.
    /// - Parameters:
    ///   - plugin: The destination plugin to enable.
    public func manuallyEnableDestination(plugin: DestinationPlugin) {
        self.store.dispatch(action: System.AddDestinationToSettingsAction(key: plugin.key))
    }
}

extension Analytics {
    /// Determine if there are any events that have yet to be sent to Segment
    public var hasUnsentEvents: Bool {
        if let segmentDest = self.find(pluginType: SegmentDestination.self) {
            if segmentDest.pendingUploads > 0 {
                return true
            }
            if segmentDest.eventCount > 0 {
                return true
            }
        }

        return storage.dataStore.hasData
    }

    /// Provides a list of finished, but unsent events.
    public var pendingUploads: [URL]? {
        return storage.read(Storage.Constants.events)?.dataFiles
    }

    /// Purge all pending event upload files.
    public func purgeStorage() {
        storage.dataStore.reset()
    }

    /// Purge a single event upload file.
    public func purgeStorage(fileURL: URL) {
        guard let dataFiles = storage.read(Storage.Constants.events)?.dataFiles else { return }
        if dataFiles.contains(fileURL) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Wait until the Analytics object has completed startup.
    /// This method is primarily useful for command line utilities where
    /// it's desirable to wait until the system is up and running
    /// before executing commands.  GUI apps could potentially use this via
    /// a background thread if needed.
    public func waitUntilStarted() {
        if let startupQueue = find(pluginType: StartupQueue.self) {
            while startupQueue.running != true {
                RunLoop.main.run(until: Date.distantPast)
            }
        }
    }
}

extension Analytics {
    /**
     Call openURL as needed or when instructed to by either UIApplicationDelegate or UISceneDelegate.
     This is necessary to track URL referrers across events.  This method will also iterate
     any plugins that are watching for openURL events.

     Example:
     ```
     func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
         let myStruct = MyStruct(options)
         analytics?.openURL(url, options: options)
         return true
     }
     ```
     */
    public func openURL<T: Codable>(_ url: URL, options: T? = nil) {
        guard let jsonProperties = try? JSON(with: options) else { return }
        guard let dict = jsonProperties.dictionaryValue else { return }
        openURL(url, options: dict)
    }

    /**
     Call openURL as needed or when instructed to by either UIApplicationDelegate or UISceneDelegate.
     This is necessary to track URL referrers across events.  This method will also iterate
     any plugins that are watching for openURL events.

     Example:
     ```
     func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
         analytics?.openURL(url, options: options)
         return true
     }
     ```
     */
    public func openURL(_ url: URL, options: [String: Any] = [:]) {
        store.dispatch(action: UserInfo.SetReferrerAction(url: url))

        // let any conforming plugins know
        apply { plugin in
            if let p = plugin as? OpeningURLs {
                p.openURL(url, options: options)
            }
        }

        var jsonProperties: JSON? = nil
        if let json = try? JSON(options) {
            do {
                jsonProperties = try json.add(value: url.absoluteString, forKey: "url")
            } catch {
                jsonProperties = json
            }
        } else {
            if let json = try? JSON(["url": url.absoluteString]) {
                jsonProperties = json
            }
        }
        track(name: "Deep Link Opened", properties: jsonProperties)
    }
}

// MARK: Private Stuff

extension Analytics {
    private func checkSharedInstance() {
        // is firstInstance a dead one?  If so, override it.
        if let firstInstance = Self.firstInstance {
            if firstInstance.isDead {
                Self.firstInstance = self
            }
        }
        // is firstInstance nil?  If so, set it.
        if Self.firstInstance == nil {
            Self.firstInstance = self
        }
    }

    /// Determines if an instance is dead.
    internal var isDead: Bool {
        return configuration.values.writeKey == Self.deadInstance
    }
    
    /// Manage active writekeys.  It's wrapped in @atomic
    internal static func isActiveWriteKey(_ writeKey: String) -> Bool {
        Self.activeWriteKeys.contains(writeKey)
    }
    
    internal static func addActiveWriteKey(_ writeKey: String) {
        Self._activeWriteKeys.mutate { keys in
            keys.append(writeKey)
        }
    }
    
    internal static func removeActiveWriteKey(_ writeKey: String) {
        Self._activeWriteKeys.mutate { keys in
            keys.removeAll { key in
                writeKey == key
            }
        }
    }
}

// MARK: Operating mode based scheduling

extension OperatingMode {
    func run(queue: DispatchQueue, task: @escaping () -> Void) {
        //
        switch self {
        case .asynchronous:
            queue.async {
                task()
            }
        case .synchronous:
            // in synchronous mode, always use our own queue to
            // prevent deadlocks.
            let workItem = DispatchWorkItem(block: task)
            OperatingMode.defaultQueue.asyncAndWait(execute: workItem)
        }
    }
}
