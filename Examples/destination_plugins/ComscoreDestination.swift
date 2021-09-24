//
//  ComscoreDestination.swift
//  ComscoreDestination
//
//  Created by Cody Garvin on 9/21/21.
//

import Segment
import ComScore
import CoreMedia

/**
 An implementation of the Comscore Analytics device mode destination as a plugin.
 */

class ComscoreDestination: DestinationPlugin {
    let timeline = Timeline()
    let type = PluginType.destination
    let key = "comScore"
    var analytics: Analytics? = nil
    
    private var comscoreSettings: ComscoreSettings?
    private var comscoreEnrichment: ComscoreEnrichment?
    private var streamAnalytics: SCORStreamingAnalytics?
    private var configurationLabels = [String: Any]()
        
    func update(settings: Settings, type: UpdateType) {
        // Skip if you have a singleton and don't want to keep updating via settings.
        guard type == .initial else { return }
        
        // Set up the enrichment plugin
        comscoreEnrichment = ComscoreEnrichment()
        analytics?.add(plugin: comscoreEnrichment!)
        
        // Grab the settings and assign them for potential later usage.
        // Note: Since integrationSettings is generic, strongly type the variable.
        guard let tempSettings: ComscoreSettings = settings.integrationSettings(forPlugin: self) else { return }
        comscoreSettings = tempSettings
        
        // Set the update mode
        if tempSettings.foregroundOnly && tempSettings.autoUpdate {
            SCORAnalytics.configuration().usagePropertiesAutoUpdateMode = .foregroundOnly
        } else if tempSettings.autoUpdate {
            SCORAnalytics.configuration().usagePropertiesAutoUpdateMode = .foregroundAndBackground
        } else {
            SCORAnalytics.configuration().usagePropertiesAutoUpdateMode = .disabled
        }
        
        SCORAnalytics.configuration().usagePropertiesAutoUpdateInterval = Int32(tempSettings.autoUpdateInterval)
        
        SCORAnalytics.configuration().liveTransmissionMode = SCORLiveTransmissionModeLan // No bridge to NS_ENUM, must use full name
        
        SCORAnalytics.configuration().applicationName = tempSettings.appName
        
        // Start off with the partner configuration
        let publisherConfiguration = SCORPublisherConfiguration { builder in
            builder?.publisherId = tempSettings.c2
            builder?.secureTransmissionEnabled = tempSettings.useHTTPS
        }
        
        let partnerConfiguration = SCORPartnerConfiguration { builder in
            builder?.partnerId = Self.partnerId
        }
        
        SCORAnalytics.configuration().addClient(with: partnerConfiguration)
        SCORAnalytics.configuration().addClient(with: publisherConfiguration)
        SCORAnalytics.start()
    }
    
    func identify(event: IdentifyEvent) -> IdentifyEvent? {
        
        if let traits = event.traits?.dictionaryValue {
            let mappedTraits = convertToStringFormatFrom(data: traits)
            for (key, value) in mappedTraits {
                SCORAnalytics.configuration().setPersistentLabelWithName(key, value: value)
                
                analytics?.log(message: "SCORAnalytics.configuration.setPersistentLabelWithName(\(key), value: \(value))",
                               kind: .debug)
            }
        }
        
        return event
    }
    
    func track(event: TrackEvent) -> TrackEvent? {
                
        // Determine if there are any video streaming calls, one is executed
        // return so the hiddenEvent can not be fired
        if let properties = event.properties {
            if parsedVideoInstruction(event: event, properties: properties) {
                return event
            }
        }
        
        var hiddenLabels = ["name": event.event]
        if let properties = event.properties?.dictionaryValue {
            hiddenLabels.merge(convertToStringFormatFrom(data: properties)) { _, new in
                new
            }
        }
        SCORAnalytics.notifyHiddenEvent(withLabels: hiddenLabels)
        analytics?.log(message: "SCORAnalytics.notifyHiddenEvent(withLabels: \(hiddenLabels))",
                       kind: .debug)
        
        return event
    }
    
    func screen(event: ScreenEvent) -> ScreenEvent? {
        
        if let _ = event.properties?.dictionaryValue {
            // TODO: Do something with properties if they exist
        }

        // TODO: Do something with name, category & properties in partner SDK
        
        return event
    }
    
    func group(event: GroupEvent) -> GroupEvent? {
        
        if let _ = event.traits?.dictionaryValue {
            // TODO: Do something with traits if they exist
        }
        
        // TODO: Do something with groupId & traits in partner SDK
        
        return event
    }
    
    func alias(event: AliasEvent) -> AliasEvent? {
        
        // TODO: Do something with previousId & userId in partner SDK
        
        return event
    }
    
    func reset() {
        // TODO: Do something with resetting partner SDK
    }
}

// Example of what settings may look like.
private struct ComscoreSettings: Codable {
    let c2: String
    let autoUpdate: Bool
    let autoUpdateInterval: Int
    let useHTTPS: Bool
    let appName: String
    let publisherSecret: String?
    let foregroundOnly: Bool
}

// Rules for converting keys and values to the proper formats that bridge
// from Segment to the Partner SDK. These are only examples.
private extension ComscoreDestination {
    
    static let partnerId = "23243060"
    
    static let adPropertiesMap = [
        "assetId": "ns_st_ami",
        "asset_id": "ns_st_ami",
        "title": "ns_st_amt",
        "publisher": "ns_st_pu"
    ]
    static let contentPropertiesMap = [
        "title": "ns_st_ep",
        "season": "ns_st_sn",
        "episode": "ns_st_en",
        "genre": "ns_st_ge",
        "program": "ns_st_pr",
        "channel": "ns_st_st",
        "publisher": "ns_st_pu",
        "fullEpisode": "ns_st_ce",
        "full_episode": "ns_st_ce",
        "podId": "ns_st_pn",
        "pod_id": "ns_st_pn"
    ]
    static let contentIdMap = [
        "assetId": "ns_st_ci",
        "asset_id": "ns_st_ci"
    ]
    static let playbackPropertiesMap = [
        "videoPlayer": "ns_st_mp",
        "video_player": "ns_st_mp",
        "sound": "ns_st_vo"
    ]
    
    static var eventNameMap = ["ADD_TO_CART": "Product Added",
                               "PRODUCT_TAPPED": "Product Tapped"]
    
    func convertToStringFormatFrom(data: Dictionary<String, Any>) -> Dictionary<String, String> {
        var returnDictionary = [String: String]()
        for (key, value) in data {
            var updatedValue = value
            if isValid(data: updatedValue) {
                if let arrayData = updatedValue as? Array<String> {
                    updatedValue = arrayData.joined(separator: ",")
                }
                returnDictionary[key] = "\(updatedValue)"
            }
        }
        
        return returnDictionary
    }
    
    func isValid(data: Any) -> Bool {
        var result = data is String || (data is Array<Any> && (data as! Array<Any>).count > 0) || data is Int || data is Double
        if result, let tempData = data as? String {
            result = !tempData.isEmpty
        }
        
        return result
    }
    
    func parsedVideoInstruction(event: TrackEvent, properties: JSON) -> Bool {
        switch event.event {
            case "Video Playback Started":
                videoPlaybackStarted(event: event, properties: properties)
                return true
            case "Video Playback Paused",
                 "Video Playback Interrupted":
                videoPlaybackPaused(event: event, properties: properties)
                return true
            case "Video Playback Buffer Started":
                videoPlaybackBufferStarted(event: event, properties: properties)
                return true
            case "Video Playback Buffer Completed":
                videoPlaybackBufferCompleted(event: event, properties: properties)
                return true
            case "Video Playback Seek Started":
                videoPlaybackSeekStarted(event: event, properties: properties)
                return true
            case "Video Playback Seek Completed",
                 "Video Playback Resumed":
                videoPlaybackSeekCompleted(event: event, properties: properties)
                return true
            case "Video Content Started":
                videoContentStarted(event: event, properties: properties)
                return true
            case "Video Content Playing":
                videoContentPlaying(event: event, properties: properties)
                return true
            case "Video Content Completed":
                videoContentCompleted(event: event, properties: properties)
                return true
            case "Video Ad Started":
                videoAdStarted(event: event, properties: properties)
                return true
            case "Video Ad Playing":
                videoAdPlaying(event: event, properties: properties)
                return true
            case "Video Ad Completed":
                videoAdCompleted(event: event, properties: properties)
                return true
            default:
                analytics?.log(message: "No video track calls", kind: .debug)
        }
        
        return false
    }

    
    // MARK: - Playback methods
    
    func videoPlaybackStarted(event: TrackEvent, properties: JSON) {
        streamAnalytics = SCORStreamingAnalytics()
        
        let convertedProperties = properties.dictionaryValue
        let map = ["ns_st_mp" : "\(convertedProperties?["video_player"] ?? "*null")",
                   "ns_st_ci" : "\(convertedProperties?["content_asset_id"] ?? "0")"]
        
        streamAnalytics?.createPlaybackSession()
        
        streamAnalytics?.configuration().addLabels(map)
        streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
        configurationLabels = configurationLabels.merging(map) { $1 }
        analytics?.log(message: "streamAnalytics.createPlaybackSessionWithLabels: \(map)", kind: .debug)
    }
    
    func videoPlaybackPaused(event: TrackEvent, properties: JSON) {
        
        if let map = mappedPlaybackProperties(event: event, properties: properties) {
            streamAnalytics?.configuration().addLabels(map)
            configurationLabels = configurationLabels.merging(map) { $1 }
            
            streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
        }
        analytics?.log(message: "streamAnalytics.notifyPause", kind: .debug)
    }
    
    func videoPlaybackBufferStarted(event: TrackEvent, properties: JSON) {
        
        if let map = mappedPlaybackProperties(event: event, properties: properties) {
            streamAnalytics?.configuration().addLabels(map)
            configurationLabels = configurationLabels.merging(map) { $1 }
            
            streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
        }
        
        movePosition(properties)
        streamAnalytics?.notifyBufferStart()
        
        analytics?.log(message: "streamAnalytics.notifyBufferStart", kind: .debug)
    }
    
    func videoPlaybackBufferCompleted(event: TrackEvent, properties: JSON) {
        
        if let map = mappedPlaybackProperties(event: event, properties: properties) {
            streamAnalytics?.configuration().addLabels(map)
            configurationLabels = configurationLabels.merging(map) { $1 }
            
            streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
        }
        
        movePosition(properties)
        streamAnalytics?.notifyBufferStop()
        
        analytics?.log(message: "streamAnalytics.notifyBufferStop", kind: .debug)
    }
    
    func videoPlaybackSeekStarted(event: TrackEvent, properties: JSON) {
        
        if let map = mappedPlaybackProperties(event: event, properties: properties) {
            streamAnalytics?.configuration().addLabels(map)
            configurationLabels = configurationLabels.merging(map) { $1 }
            
            streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
        }
        
        seekPosition(properties)
        streamAnalytics?.notifySeekStart()
        
        analytics?.log(message: "streamAnalytics.notifySeekStart", kind: .debug)
    }
    
    func videoPlaybackSeekCompleted(event: TrackEvent, properties: JSON) {
        
        if let map = mappedPlaybackProperties(event: event, properties: properties) {
            streamAnalytics?.configuration().addLabels(map)
            configurationLabels = configurationLabels.merging(map) { $1 }
            
            streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
        }
        
        seekPosition(properties)
        streamAnalytics?.notifyPlay()
        
        analytics?.log(message: "streamAnalytics.notifyPlay", kind: .debug)
    }
    
    // MARK: - Content Methods
    func videoContentStarted(event: TrackEvent, properties: JSON) {

        
        if let map = mappedContentProperties(event: event, properties: properties) {
            streamAnalytics?.configuration().addLabels(map)
            configurationLabels = configurationLabels.merging(map) { $1 }
            
            streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
        }
        
        movePosition(properties)
        streamAnalytics?.notifyPlay()
        
        analytics?.log(message: "streamAnalytics.notifyPlay", kind: .debug)
    }

    func videoContentPlaying(event: TrackEvent, properties: JSON) {
        
        if let map = mappedContentProperties(event: event, properties: properties) {
            streamAnalytics?.configuration().addLabels(map)
            configurationLabels = configurationLabels.merging(map) { $1 }
        
            // The presence of ns_st_ad on the StreamingAnalytics's asset means that we just exited an ad break, so
            // we need to call setAsset with the content metadata.  If ns_st_ad is not present, that means the last
            // observed event was related to content, in which case a setAsset call should not be made (because asset
            // did not change).
            if let _ = configurationLabels["ns_st_ad"] {
                streamAnalytics?.setMetadata(instantiateContentMetaData(properties: map))
            }
        }
        
        movePosition(properties)
        streamAnalytics?.notifyPlay()
        
        analytics?.log(message: "streamAnalytics.notifyPlay", kind: .debug)
    }
    
    func videoContentCompleted(event: TrackEvent, properties: JSON) {
        streamAnalytics?.notifyEnd()
        configurationLabels = [String: Any]()
        analytics?.log(message: "streamAnalytics.notifyPlay", kind: .debug)
    }
    
    // MARK: - Ad Methods
    
    func videoAdStarted(event: TrackEvent, properties: JSON) {
        
        // The ID for content is not available on Ad Start events, however it will be available on the current
        // StreamingAnalytics's asset. This is because ns_st_ci will have already been set via asset_id in a
        // Content Started calls (if this is a mid or post-roll), or via content_asset_id on Video Playback
        // Started (if this is a pre-roll).
        let contentId = configurationLabels["ns_st_ci"] as? String ?? "0"

        if var map = mappedAdProperties(event: event, properties: properties) {
            map["ns_st_ci"] = contentId
            let contentMetadata = instantiateContentMetaData(properties: map)
            
            if let tempProperties = properties.dictionaryValue {
                var mediaType = SCORStreamingAdvertisementType.other
                if let adType = tempProperties["type"] as? String {
                    if adType == "pre-roll" {
                        mediaType = SCORStreamingAdvertisementType.onDemandPreRoll
                    } else if adType == "mid-roll" {
                        mediaType = SCORStreamingAdvertisementType.onDemandMidRoll
                    } else if adType == "post-roll" {
                        mediaType = SCORStreamingAdvertisementType.onDemandPostRoll
                    }
                    
                }
                
                let advertisingMetadata = SCORStreamingAdvertisementMetadata { builder in
                    builder?.setMediaType(mediaType)
                    builder?.setCustomLabels(map)
                    builder?.setRelatedContentMetadata(contentMetadata)
                }
                
                streamAnalytics?.setMetadata(advertisingMetadata)
            }

        }
        
        movePosition(properties)
        streamAnalytics?.notifyPlay()
        
        analytics?.log(message: "streamAnalytics.notifyPlay", kind: .debug)
    }

    func videoAdPlaying(event: TrackEvent, properties: JSON) {
        movePosition(properties)
        streamAnalytics?.notifyPlay()
        analytics?.log(message: "streamAnalytics.notifyPlay", kind: .debug)
    }
    
    func videoAdCompleted(event: TrackEvent, properties: JSON) {
        movePosition(properties)
        streamAnalytics?.notifyEnd()
        analytics?.log(message: "streamAnalytics.notifyEnd", kind: .debug)
    }
}

// MARK: - Helper methods
private extension ComscoreDestination {
    
    func mappedPlaybackProperties(event: TrackEvent, properties: JSON) -> Dictionary<String, String>? {
        // Pull out the values for the event out of the enrichment plugin
        guard let options = comscoreEnrichment?.fetchAndRemoveMetricsFor(key: event.messageId ?? "0") else {
            return nil
        }
        
        var bps = "*null"
        var fullscreen = "norm"
        let convertedProperties = properties.dictionaryValue
        if let tempProperties = properties.dictionaryValue {
            bps = convertFromKBPSToBPS(source: tempProperties, key: "bitrate")
            fullscreen = returnFullScreenStatus(source: tempProperties, key: "full_screen")
        }
        let returnMap = ["ns_st_mp" : "\(convertedProperties?["video_player"] ?? "*null")",
                         "ns_st_vo" : "\(convertedProperties?["sound"] ?? "*null")",
                         "ns_st_br" : bps,
                         "ns_st_ws" : fullscreen,
                         "c3" : "\(options["c3"] ?? "*null")",
                         "c4" : "\(options["c4"] ?? "*null")",
                         "c6" : "\(options["c6"] ?? "*null")"]
        
        return returnMap
    }
    
    func mappedContentProperties(event: TrackEvent, properties: JSON) -> Dictionary<String, String>? {
        // Pull out the values for the event out of the enrichment plugin
        guard let options = comscoreEnrichment?.fetchAndRemoveMetricsFor(key: event.messageId ?? "0") else {
            return nil
        }
        
        var totalLength = "0"
        let convertedProperties = properties.dictionaryValue
        if let tempProperties = properties.dictionaryValue {
            totalLength = convertFromSecondsToMilliseconds(source: tempProperties, key: "total_length")
        }
        let returnMap = ["ns_st_ci" : "\(convertedProperties?["asset_id"] ?? "0")",
                         "ns_st_ep" : "\(convertedProperties?["title"] ?? "*null")",
                         "ns_st_sn" : "\(convertedProperties?["season"] ?? "*null")",
                         "ns_st_en" : "\(convertedProperties?["episode"] ?? "*null")",
                         "ns_st_ge" : "\(convertedProperties?["genre"] ?? "*null")",
                         "ns_st_pr" : "\(convertedProperties?["program"] ?? "*null")",
                         "ns_st_pn" : "\(convertedProperties?["pod_id"] ?? "*null")",
                         "ns_st_ce" : "\(convertedProperties?["full_episode"] ?? "*null")",
                         "ns_st_cl" : totalLength,
                         "ns_st_pu" : "\(convertedProperties?["publisher"] ?? "*null")",
                         "ns_st_st" : "\(convertedProperties?["channel"] ?? "*null")",
                         "ns_st_ddt" : "\(options["digitalAirdate"] ?? "*null")",
                         "ns_st_tdt" : "\(options["tvAirdate"] ?? "*null")",
                         "c3" : "\(options["c3"] ?? "*null")",
                         "c4" : "\(options["c4"] ?? "*null")",
                         "c6" : "\(options["c6"] ?? "*null")",
                         "ns_st_ct" : "\(options["contentClassificationType"] ?? "vc00")"]
        
        return returnMap
    }
    
    func mappedAdProperties(event: TrackEvent, properties: JSON) -> Dictionary<String, String>? {
        // Pull out the values for the event out of the enrichment plugin
        guard let options = comscoreEnrichment?.fetchAndRemoveMetricsFor(key: event.messageId ?? "0") else {
            return nil
        }
        
        var adType = "1"
        var totalLength = "0"
        let convertedProperties = properties.dictionaryValue
        if let tempProperties = properties.dictionaryValue {
            adType = defaultAdType(source: tempProperties, key: "type")
            totalLength = convertFromSecondsToMilliseconds(source: tempProperties, key: "total_length")
        }
        let returnMap = ["ns_st_ami" : "\(convertedProperties?["asset_id"] ?? "*null")",
                         "ns_st_ad" : adType,
                         "ns_st_cl" : totalLength,
                         "ns_st_amt" : "\(convertedProperties?["title"] ?? "*null")",
                         "ns_st_pu" : "\(convertedProperties?["publisher"] ?? "*null")",
                         "c3" : "\(options["c3"] ?? "*null")",
                         "c4" : "\(options["c4"] ?? "*null")",
                         "c6" : "\(options["c6"] ?? "*null")",
                         "ns_st_ct" : "\(options["contentClassificationType"] ?? "vc00")"]
        
        return returnMap
    }

    
    // comScore expects bitrate to converted from KBPS be BPS
    func convertFromKBPSToBPS(source: [String: Any], key: String) -> String {
        var returnValue = "*null"
        if let kbps = source[key] as? Int {
            returnValue = "\(kbps * 1000)"
        }
        
        return returnValue
    }
    
    // comScore expects milliseconds to be converted from seconds to milliseconds
    func convertFromSecondsToMilliseconds(source: [String: Any], key: String) -> String {
        var returnValue = "0"
        if let seconds = source[key] as? Int {
            returnValue = "\(seconds * 1000)"
        }
        
        return returnValue
    }
    
    func returnFullScreenStatus(source: [String: Any], key: String) -> String {
        if let value = source[key] as? Bool,
        value == true {
            return "full"
        } else {
            return "norm"
        }
    }
    
    func instantiateContentMetaData(properties: [String: Any]) -> SCORStreamingContentMetadata? {
        let contentMetaData = SCORStreamingContentMetadata { builder in
            builder?.setCustomLabels(properties)
            if properties.keys.contains("ns_st_ge") {
                builder?.setGenreName("ns_st_ge")
            }
        }
        return contentMetaData
    }
    
    func movePosition(_ properties: JSON) {
        if let position = properties.dictionaryValue?["position"] as? Int {
            streamAnalytics?.start(fromPosition: position)
        }
    }
    
    func seekPosition(_ properties: JSON) {
        if let position = properties.dictionaryValue?["seek_position"] as? Int {
            streamAnalytics?.start(fromPosition: position)
        }
    }
    
    func defaultAdType(source: [String: Any], key: String) -> String {
        var returnAdType = "1"
        
        if let value = source[key] as? String {
            if value == "pre-roll" || value == "mid-roll" || value == "post-roll" {
                returnAdType = value
            }
        }
        
        return returnAdType
    }
}

// MARK: - Comscore Enrichment Plugin
private class ComscoreEnrichment: EventPlugin {
    var type: PluginType = .before
    var analytics: Analytics?
    
    static let comscoreKey = "videoMetricDictionaryClassification"
    
    // The dictionary being stored off should look like:
    private var videoMetrics = [String: [String: String]]()
    
    func track(event: TrackEvent) -> TrackEvent? {
        
        var returnEvent = event
        if let properties = event.properties?.dictionaryValue,
           var comscoreProperties = properties[Self.comscoreKey] as? [String: String],
           !comscoreProperties.isEmpty, let messageId = event.messageId {
            
            // Store off the options
            videoMetrics[messageId] = comscoreProperties
            
            // Filter out the properties
            comscoreProperties = comscoreProperties.filter { (key, value) in
                return key != Self.comscoreKey
            }
            
            // Build the updated comscore properties back into JSON
            do {
                returnEvent.properties = try JSON(comscoreProperties)
            } catch {
                analytics?.log(message: "Could not convert comscore properties", kind: .debug)
            }
        }
        return returnEvent
    }
    
    
    /// Fetches the appropriate options payload if one existed for that particular message Id
    /// - Parameter key: The messageId related to the original event
    /// - Returns: An optional payload if one is found for the messageId
    func fetchAndRemoveMetricsFor(key: String) -> [String: String]? {
        let returnMetrics = videoMetrics[key]
        
        // Remove the metrics now
        videoMetrics.removeValue(forKey: key)
        
        return returnMetrics
    }
}
