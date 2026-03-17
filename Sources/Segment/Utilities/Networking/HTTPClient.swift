//
//  HTTPClient.swift
//  Segment-Tests
//
//  Created by Cody Garvin on 12/28/20.
//

import Foundation
#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

public enum HTTPClientErrors: Error {
    case badSession
    case failedToOpenBatch
    case statusCode(code: Int)
    case unknown(error: Error)
    case rateLimited
    case badRequest
}

public class HTTPClient {
    private static let defaultAPIHost = "api.segment.io/v1"
    private static let defaultCDNHost = "cdn-settings.segment.com/v1"

    internal var session: any HTTPSession
    private var apiHost: String
    private var apiKey: String
    private var cdnHost: String

    private weak var analytics: Analytics?

    private var retryStateMachine: RetryStateMachine?
    private var retryState: RetryState
    private let timeProvider: TimeProvider

    init(analytics: Analytics, timeProvider: TimeProvider = SystemTimeProvider()) {
        self.analytics = analytics

        self.apiKey = analytics.configuration.values.writeKey
        self.apiHost = analytics.configuration.values.apiHost
        self.cdnHost = analytics.configuration.values.cdnHost

        self.session = analytics.configuration.values.httpSession()
        self.timeProvider = timeProvider

        // Initialize retry system if httpConfig provided
        if let httpConfig = analytics.configuration.values.httpConfig {
            self.retryStateMachine = RetryStateMachine(config: httpConfig, timeProvider: timeProvider)
            self.retryState = analytics.storage.loadRetryState()
        } else {
            self.retryStateMachine = nil
            self.retryState = RetryState() // Legacy mode
        }
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
    func startBatchUpload(writeKey: String, batch: URL, completion: @escaping (_ result: Result<Bool, Error>) -> Void) -> (any DataTask)? {
        guard let uploadURL = segmentURL(for: apiHost, path: "/b") else {
            self.analytics?.reportInternalError(HTTPClientErrors.failedToOpenBatch)
            completion(.failure(HTTPClientErrors.failedToOpenBatch))
            return nil
        }

        // Check if we should upload this batch
        if let stateMachine = retryStateMachine {
            let (decision, updatedState) = stateMachine.shouldUploadBatch(state: retryState, batchFile: batch.lastPathComponent)
            retryState = updatedState
            analytics?.storage.saveRetryState(retryState)

            switch decision {
            case .skipAllBatches, .skipThisBatch:
                completion(.failure(HTTPClientErrors.rateLimited))
                return nil
            case .dropBatch:
                completion(.failure(HTTPClientErrors.badRequest))
                return nil
            case .proceed:
                break // Continue with upload
            }
        }

        let urlRequest = configuredRequest(for: uploadURL, method: "POST")

        let batchFileName = batch.lastPathComponent
        let dataTask = session.uploadTask(with: urlRequest, fromFile: batch) { [weak self] (data, response, error) in
            guard let self else { return }
            handleResponse(data: data, response: response, error: error, url: uploadURL, batchFile: batchFileName, completion: completion)
        }

        dataTask.resume()
        return dataTask
    }
    
    /// Starts an upload of events. Responds appropriately if successful or not. If not, lets the respondant
    /// know if the task should be retried or not based on the response.
    /// - Parameters:
    ///   - key: The write key the events are assocaited with.
    ///   - batch: The array of the events, considered a batch of events.
    ///   - completion: The closure executed when done. Passes if the task should be retried or not if failed.
    @discardableResult
    func startBatchUpload(writeKey: String, data: Data, completion: @escaping (_ result: Result<Bool, Error>) -> Void) -> (any UploadTask)? {
        guard let uploadURL = segmentURL(for: apiHost, path: "/b") else {
            self.analytics?.reportInternalError(HTTPClientErrors.failedToOpenBatch)
            completion(.failure(HTTPClientErrors.failedToOpenBatch))
            return nil
        }
          
        let urlRequest = configuredRequest(for: uploadURL, method: "POST")

        let dataTask = session.uploadTask(with: urlRequest, from: data) { [weak self] (data, response, error) in
            guard let self else { return }
            // Data-based upload doesn't have a batch file, so pass empty string
            handleResponse(data: data, response: response, error: error, url: uploadURL, batchFile: "", completion: completion)
        }
        
        dataTask.resume()
        return dataTask
    }
    
    private func extractRetryAfter(from response: HTTPURLResponse) -> Int? {
        return response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
    }

    private func handleResponse(data: Data?, response: URLResponse?, error: Error?, url: URL?, batchFile: String, completion: @escaping (_ result: Result<Bool, Error>) -> Void) {
        if let error = error {
            analytics?.log(message: "Error uploading request \(error.localizedDescription).")
            analytics?.reportInternalError(AnalyticsError.networkUnknown(url, error))
            completion(.failure(HTTPClientErrors.unknown(error: error)))
        } else if let httpResponse = response as? HTTPURLResponse {
            // Update retry state after response
            if let stateMachine = retryStateMachine {
                let responseInfo = ResponseInfo(
                    statusCode: httpResponse.statusCode,
                    retryAfterSeconds: extractRetryAfter(from: httpResponse),
                    batchFile: batchFile,
                    currentTime: timeProvider.now()
                )
                retryState = stateMachine.handleResponse(state: retryState, response: responseInfo)
                analytics?.storage.saveRetryState(retryState)
            }

            switch (httpResponse.statusCode) {
            case 1..<300:
                completion(.success(true))
                return
            case 300..<400:
                analytics?.reportInternalError(AnalyticsError.networkUnexpectedHTTPCode(url, httpResponse.statusCode))
                completion(.failure(HTTPClientErrors.statusCode(code: httpResponse.statusCode)))
            case 429:
                analytics?.reportInternalError(AnalyticsError.networkServerLimited(url, httpResponse.statusCode))
                completion(.failure(HTTPClientErrors.statusCode(code: httpResponse.statusCode)))
            default:
                analytics?.reportInternalError(AnalyticsError.networkServerRejected(url, httpResponse.statusCode))
                completion(.failure(HTTPClientErrors.statusCode(code: httpResponse.statusCode)))
            }
        }
    }
    
    func settingsFor(writeKey: String, completion: @escaping (Bool, Settings?) -> Void) {
        guard let settingsURL = segmentURL(for: cdnHost, path: "/projects/\(writeKey)/settings") else {
            completion(false, nil)
            return
        }

        let urlRequest = configuredRequest(for: settingsURL, method: "GET")

        let dataTask = session.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            if let error = error {
                self?.analytics?.reportInternalError(AnalyticsError.settingsFail(AnalyticsError.networkUnknown(settingsURL, error)))
                completion(false, nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode > 300 {
                    self?.analytics?.reportInternalError(AnalyticsError.settingsFail(AnalyticsError.networkUnexpectedHTTPCode(settingsURL, httpResponse.statusCode)))
                    completion(false, nil)
                    return
                }
            }

            guard let data = data else {
                self?.analytics?.reportInternalError(AnalyticsError.settingsFail(AnalyticsError.networkInvalidData))
                completion(false, nil)
                return
            }

            do {
                let responseJSON = try JSONDecoder.default.decode(Settings.self, from: data)
                completion(true, responseJSON)
            } catch {
                self?.analytics?.reportInternalError(AnalyticsError.settingsFail(AnalyticsError.jsonUnableToDeserialize(error)))
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

    internal func configuredRequest(for url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = method
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("analytics-ios/\(Analytics.version())", forHTTPHeaderField: "User-Agent")
        request.addValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        if let requestFactory = analytics?.configuration.values.requestFactory {
            request = requestFactory(request)
        }

        return request
    }
}
