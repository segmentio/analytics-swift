//
//  HTTPClient.swift
//  Segment-Tests
//
//  Created by Cody Garvin on 12/28/20.
//

import Foundation

enum HTTPClientErrors: Error {
    case badSession
}

public class HTTPClient {
    
    static let segmentAPIBaseHost = "https://api.segment.io/v1"
    static let segmentCDNBaseHost = "https://cdn-settings.segment.com/v1"
    
    public var sessionDelegate: URLSessionDelegate?
    
    private var writeKeySessions = [String: URLSession]()
    private var baseURL: URL?
    private let analytics: Analytics
    
    init(analytics: Analytics, url: URL? = nil) {
        
        self.analytics = analytics
        
        // Set with the proper URL
        if let baseURL = url {
            self.baseURL = baseURL
        } else {
            self.baseURL = URL(string: Self.segmentAPIBaseHost)
        }
    }
    
    
    /// Starts an upload of events. Responds appropriately if successful or not. If not, lets the respondant
    /// know if the task should be retried or not based on the response.
    /// - Parameters:
    ///   - key: The write key the events are assocaited with.
    ///   - batch: The array of the events, considered a batch of events.
    ///   - completion: The closure executed when done. Passes if the task should be retried or not if failed.
    @discardableResult
    func startBatchUpload(writeKey: String, batch: URL, completion: @escaping (_ succeeded: Bool) -> Void) -> URLSessionDataTask? {
        
        guard var uploadURL = URL(string: HTTPClient.segmentAPIBaseHost) else {
            completion(false)
            return nil
        }
                
        uploadURL = uploadURL.appendingPathComponent("/batch")
        var urlRequest = URLRequest(url: uploadURL)
        urlRequest.httpMethod = "POST"
        
        guard let session = try? configuredSession(for: writeKey) else {
            completion(false)
            return nil
        }
        
        let dataTask = session.uploadTask(with: urlRequest, fromFile: batch) { [weak self] (data, response, error) in
            if let error = error {
                self?.analytics.log(message: "Error uploading request \(error.localizedDescription).")
                completion(true)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print(httpResponse.debugDescription)
                print(String(data: data!, encoding: .utf8) ?? "")

                switch (httpResponse.statusCode) {
                case 1..<300:
                    completion(true)
                    return
                case 300..<400:
                    self?.analytics.log(message: "Server responded with unexpected HTTP code \(httpResponse.statusCode).")
                    completion(false)
                case 429:
                    self?.analytics.log(message: "Server limited client with response code \(httpResponse.statusCode).")
                    completion(false)
                case 400..<500:
                    self?.analytics.log(message: "Server rejected payload with HTTP code \(httpResponse.statusCode).")
                    completion(false)
                default: // All 500 codes
                    self?.analytics.log(message: "Server rejected payload with HTTP code \(httpResponse.statusCode).")
                    completion(false)
                }
            }
        }
        
        dataTask.resume()
        return dataTask
    }
    
    func settingsFor(writeKey: String, completion: @escaping (Bool, RawSettings?) -> Void) {
        
        // Change the key specific to settings so it can be fetched separately
        // from write key sessions for uploading.
        let settingsKey = "\(writeKey)_settings"
        
        guard var settingsURL = URL(string: HTTPClient.segmentCDNBaseHost) else {
            completion(false, nil)
            return
        }
        
        settingsURL = settingsURL.appendingPathComponent("/projects/\(writeKey)/settings")
        var urlRequest = URLRequest(url: settingsURL)
        urlRequest.httpMethod = "GET"

        guard let session = try? configuredSession(for: settingsKey) else {
            completion(false, nil)
            return
        }
        
        let dataTask = session.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            if let error = error {
                self?.analytics.log(message: "Error fetching settings \(error.localizedDescription).")
                completion(false, nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode > 300 {
                    self?.analytics.log(message: "Server responded with unexpected HTTP code \(httpResponse.statusCode).")
                    completion(false, nil)
                    return
                }
            }

            guard let data = data, let responseJSON = try? JSONDecoder().decode(RawSettings.self, from: data) else {
                self?.analytics.log(message: "Error deserializing settings.")
                completion(false, nil)
                return
            }
            
            completion(true, responseJSON)
        }
        
        dataTask.resume()
    }
    
    deinit {
        // finish any tasks that may be processing
        for session in writeKeySessions.values {
            session.finishTasksAndInvalidate()
        }
    }
}

extension HTTPClient {

    fileprivate static var hostKey: String {
        "segment_apihost"
    }

    static func authorizationHeaderForWriteKey(_ key: String) -> String {
        
        var returnHeader: String = ""
        
        let rawHeader = "\(key):"
        if let encodedRawHeader = rawHeader.data(using: .utf8) {
            returnHeader = encodedRawHeader.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        }
        
        return returnHeader
    }
    
    internal static func saveAPIHost(_ host: String) {
        
        var updatedHost = host
        if host.isEmpty {
            return
        }
        if !host.contains("https://") {
            // strip out a potential http://
            updatedHost = host.replacingOccurrences(of: "http://", with: "")
            updatedHost.append("https://")
        }
        UserDefaults.standard.setValue(updatedHost, forKey: hostKey)
    }
    
    internal static func getAPIHost() -> String {
        
        var returnResult: String
        let defaults = UserDefaults.standard
        let result = defaults.string(forKey: hostKey)
        
        if let result = result {
            returnResult = result
        } else {
            returnResult = segmentAPIBaseHost
        }
        return returnResult
    }
}

extension HTTPClient {
    
    private func configuredSession(for writeKey: String) throws -> URLSession {
        
        if !writeKeySessions.keys.contains(writeKey) {
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = [/*"Accept-Encoding": "gzip",
                                                   "Content-Encoding": "gzip",*/
                                                   "Content-Type": "application/json; charset=utf-8",
                                                   "Authorization": "Basic \(Self.authorizationHeaderForWriteKey(writeKey))",
                                                   "User-Agent": "analytics-ios/\(Analytics.version())"]
            let session = URLSession.init(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
            writeKeySessions[writeKey] = session
        }
        
        guard let session = writeKeySessions[writeKey] else {
            throw HTTPClientErrors.badSession
        }
        
        return session
    }
}
