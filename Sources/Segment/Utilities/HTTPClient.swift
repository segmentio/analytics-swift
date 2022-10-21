//
//  HTTPClient.swift
//  Segment-Tests
//
//  Created by Cody Garvin on 12/28/20.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

enum HTTPClientErrors: Error {
    case badSession
    case failedToOpenBatch
    case statusCode(code: Int)
}

public class HTTPClient {
    private static let defaultAPIHost = "api.segment.io/v1"
    private static let defaultCDNHost = "cdn-settings.segment.com/v1"
    
    internal var session: URLSession
    private var apiHost: String
    private var apiKey: String
    private var cdnHost: String
    
    private weak var analytics: Analytics?
    
    init(analytics: Analytics, apiKey: String? = nil, apiHost: String? = nil, cdnHost: String? = nil) {
        self.analytics = analytics
        
        if let apiKey = apiKey {
            self.apiKey = apiKey
        } else {
            self.apiKey = analytics.configuration.values.writeKey
        }
        
        if let apiHost = apiHost {
            self.apiHost = apiHost
        } else {
            self.apiHost = Self.defaultAPIHost
        }
        
        if let cdnHost = cdnHost {
            self.cdnHost = cdnHost
        } else {
            self.cdnHost = Self.defaultCDNHost
        }
        
        self.session = Self.configuredSession(for: self.apiKey)
    }
    
    func segmentURL(for host: String, path: String) -> URL? {
        let s = "https://\(host)\(path)"
        let result = URL(string: s)
        return result
    }
    
    
    /// Starts an upload of events. Responds appropriately if successful or not. If not, lets the respondant
    /// know if the task should be retried or not based on the response.
    /// - Parameters:
    ///   - key: The write key the events are assocaited with.
    ///   - batch: The array of the events, considered a batch of events.
    ///   - completion: The closure executed when done. Passes if the task should be retried or not if failed.
    @discardableResult
    func startBatchUpload(writeKey: String, batch: URL, completion: @escaping (_ result: Result<Bool, Error>) -> Void) -> URLSessionDataTask? {
        guard let uploadURL = segmentURL(for: apiHost, path: "/b") else {
            completion(.failure(HTTPClientErrors.failedToOpenBatch))
            return nil
        }
                
        var urlRequest = URLRequest(url: uploadURL)
        urlRequest.httpMethod = "POST"
        
        let dataTask = session.uploadTask(with: urlRequest, fromFile: batch) { [weak self] (data, response, error) in
            if let error = error {
                self?.analytics?.log(message: "Error uploading request \(error.localizedDescription).")
                completion(.failure(error))
            } else if let httpResponse = response as? HTTPURLResponse {
                switch (httpResponse.statusCode) {
                case 1..<300:
                    completion(.success(true))
                    return
                case 300..<400:
                    self?.analytics?.reportInternalError(AnalyticsError.networkUnexpectedHTTPCode(httpResponse.statusCode))
                    completion(.failure(HTTPClientErrors.statusCode(code: httpResponse.statusCode)))
                case 429:
                    self?.analytics?.reportInternalError(AnalyticsError.networkServerLimited(httpResponse.statusCode))
                    completion(.failure(HTTPClientErrors.statusCode(code: httpResponse.statusCode)))
                default:
                    self?.analytics?.reportInternalError(AnalyticsError.networkServerRejected(httpResponse.statusCode))
                    completion(.failure(HTTPClientErrors.statusCode(code: httpResponse.statusCode)))
                }
            }
        }
        
        dataTask.resume()
        return dataTask
    }
    
    func settingsFor(writeKey: String, completion: @escaping (Bool, Settings?) -> Void) {
        guard let settingsURL = segmentURL(for: cdnHost, path: "/projects/\(writeKey)/settings") else {
            completion(false, nil)
            return
        }
        
        var urlRequest = URLRequest(url: settingsURL)
        urlRequest.httpMethod = "GET"

        let dataTask = session.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            if let error = error {
                self?.analytics?.reportInternalError(AnalyticsError.networkUnknown(error))
                completion(false, nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode > 300 {
                    self?.analytics?.reportInternalError(AnalyticsError.networkUnexpectedHTTPCode(httpResponse.statusCode))
                    completion(false, nil)
                    return
                }
            }

            guard let data = data else {
                self?.analytics?.reportInternalError(AnalyticsError.networkInvalidData)
                completion(false, nil)
                return
            }
            
            do {
                let responseJSON = try JSONDecoder().decode(Settings.self, from: data)
                completion(true, responseJSON)
            } catch {
                self?.analytics?.reportInternalError(AnalyticsError.jsonUnableToDeserialize(error))
                completion(false, nil)
                return
            }
            
        }
        
        dataTask.resume()
    }
    
    deinit {
        // finish any tasks that may be processing
        session.finishTasksAndInvalidate()
    }
}


extension HTTPClient {
    static func authorizationHeaderForWriteKey(_ key: String) -> String {
        var returnHeader: String = ""
        let rawHeader = "\(key):"
        if let encodedRawHeader = rawHeader.data(using: .utf8) {
            returnHeader = encodedRawHeader.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        }
        return returnHeader
    }
    
    internal static func getDefaultAPIHost() -> String {
        return Self.defaultAPIHost
    }
    
    internal static func getDefaultCDNHost() -> String {
        return Self.defaultCDNHost
    }
    
    internal static func configuredSession(for writeKey: String) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForResource = 30
        configuration.timeoutIntervalForRequest = 60
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json; charset=utf-8",
                                               "Authorization": "Basic \(Self.authorizationHeaderForWriteKey(writeKey))",
                                               "User-Agent": "analytics-ios/\(Analytics.version())"]
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        return session
    }
}
