import Foundation

#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

public protocol DataTask {
    var state: URLSessionTask.State { get }
    func resume()
}

public protocol UploadTask: DataTask {}

// An enumeration of default `HTTPSession` configurations to be used
// This can be extended buy consumer to easily refer back to their configured session.
public enum HTTPSessions {
    /// An implementation of `HTTPSession` backed by Apple's `URLSession`.
    public static func urlSession() -> any HTTPSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 2
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        return session
    }
}

public protocol HTTPSession {
    associatedtype DataTaskType: DataTask
    associatedtype UploadTaskType: UploadTask
    
    func uploadTask(with request: URLRequest, fromFile file: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> UploadTaskType
    func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> UploadTaskType
    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> DataTaskType
    func finishTasksAndInvalidate()
}
