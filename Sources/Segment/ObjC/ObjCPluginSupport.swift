//
//  ObjCPlugin.swift
//  
//
//  Created by Brandon Sneed on 3/14/23.
//

#if !os(Linux)

import Foundation
import Sovran

internal class ObjCShimPlugin: Plugin, Subscriber {
    var type: PluginType = .enrichment
    var analytics: Analytics? = nil
    var executionBlock: (([String: Any]?) -> [String: Any]?)? = nil
    
    required init(middleware: @escaping ([String: Any]?) -> [String: Any]?) {
        executionBlock = middleware
    }
    
    func execute<T>(event: T?) -> T? where T : RawEvent {
        // is our event actually valid?
        guard let event = event else { return event }
        // do we actually have an execution block?
        guard let executionBlock = executionBlock else { return event }
        // can we conver this to a JSON dictionary?
        guard let dictEvent = try? JSON(with: event).dictionaryValue else { return event }
        // is it valid json?
        guard JSONSerialization.isValidJSONObject(dictEvent as Any) == true else { return event }
        // run the execution block, a nil result tells us to drop the event.
        guard let result = executionBlock(dictEvent) else { return nil }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
            let decoder = JSONDecoder()
            var newEvent: RawEvent? = nil
            switch event {
                case is IdentifyEvent:
                    newEvent = try? decoder.decode(IdentifyEvent.self, from: jsonData)
                case is TrackEvent:
                    newEvent = try? decoder.decode(TrackEvent.self, from: jsonData)
                case is ScreenEvent:
                    newEvent = try? decoder.decode(ScreenEvent.self, from: jsonData)
                case is AliasEvent:
                    newEvent = try? decoder.decode(AliasEvent.self, from: jsonData)
                case is GroupEvent:
                    newEvent = try? decoder.decode(GroupEvent.self, from: jsonData)
                default:
                    break
            }
            // return the decoded event ...
            return newEvent as? T
        } else {
            // we weren't able to serialize, so return the original event.
            return event
        }
    }
}

// MARK: - ObjC Plugin Functionality

@objc
extension ObjCAnalytics {
    /// This method allows you to add middleware to an Analytics instance, similar to Analytics-iOS.
    /// However, it is **strongly encouraged** that Enrichments/Plugins/Middlewares be written in swift
    /// to avoid the overhead of type conversion back and forth.  This exists solely for compatibility
    /// purposes.
    ///
    /// Example:
    ///    [self.analytics addSourceMiddleware:^NSDictionary<NSString *,id> * _Nullable(NSDictionary<NSString *,id> * _Nullable event) {
    ///        // drop all events named booya
    ///        NSString *eventType = event[@"type"];
    ///        if ([eventType isEqualToString:@"track"]) {
    ///            NSString *eventName = event[@"event"];
    ///            if ([eventName isEqualToString:@"booya"]) {
    ///                return nil;
    ///            }
    ///        }
    ///        return event;
    ///    }];
    ///
    /// - Parameter middleware: The middleware to execute at the source level.
    @objc(addSourceMiddleware:)
    public func addSourceMiddleware(middleware: @escaping ((_ event: [String: Any]?) -> [String: Any]?)) {
        analytics.add(plugin: ObjCShimPlugin(middleware: middleware))
    }
    
    /// This method allows you to add middleware to an Analytics instance, similar to Analytics-iOS.
    /// However, it is **strongly encouraged** that Enrichments/Plugins/Middlewares be written in swift
    /// to avoid the overhead of type conversion back and forth.  This exists solely for compatibility
    /// purposes.
    ///
    /// Example:
    ///    [self.analytics addDestinationMiddleware:^NSDictionary<NSString *,id> * _Nullable(NSDictionary<NSString *,id> * _Nullable event) {
    ///        // drop all events named booya on the amplitude destination
    ///        NSString *eventType = event[@"type"];
    ///        if ([eventType isEqualToString:@"track"]) {
    ///            NSString *eventName = event[@"event"];
    ///            if ([eventName isEqualToString:@"booya"]) {
    ///                return nil;
    ///            }
    ///        }
    ///        return event;
    ///    }, forKey: @"Amplitude"];
    ///
    /// - Parameters:
    ///   - middleware: The middleware to execute at the source level.
    ///   - destinationKey: A string value representing the destination.  ie: @"Amplitude"
    @objc(addDestinationMiddleware:forKey:)
    public func addDestinationMiddleware(middleware: @escaping ((_ event: [String: Any]?) -> [String: Any]?), destinationKey: String) {
        // couldn't find the destination they wanted
        guard let dest = analytics.find(key: destinationKey) else { return }
        _ = dest.add(plugin: ObjCShimPlugin(middleware: middleware))
    }
    
    @objc(addDestination:)
    public func addDestination(_ destination: ObjCDestination) {
        guard let bouncer = destination as? ObjCDestinationShim else { return }
        let dest = bouncer.instance()
        analytics.add(plugin: dest)
    }
}


#endif
