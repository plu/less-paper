import AsyncAlgorithms
import Dependencies
import Foundation
import Security
import UIKit

public extension DependencyValues {
    var apiSessionDelegate: ApiSessionDelegate {
        get { self[ApiSessionDelegate.self] }
        set { self[ApiSessionDelegate.self] = newValue }
    }
}

extension ApiSessionDelegate: DependencyKey {
    public static let liveValue = ApiSessionDelegate()
}

public final class ApiSessionDelegate: NSObject, URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        Task {
            @Dependency(\.certificateApprovalChannel)
            var channel

            let request = CertificateApprovalRequest(
                challenge: challenge,
                completion: completionHandler,
                url: task.currentRequest?.url
            )

            await channel.send(.request(request))
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // Refuse redirects that leave the original request's host. Same host with a different
        // scheme or port is fine - paperless behind a proxy that terminates TLS answers with an
        // https URL for an http request all the time. The proxy's login lives at a different
        // name, and that is the one this catches. The task then completes with the 3xx itself,
        // which validateResponse in ApiClientDelegate reads as the forward-auth bounce.
        let originalHost = task.originalRequest?.url?.host()
        let redirectHost = request.url?.host()

        if let originalHost, let redirectHost, originalHost == redirectHost {
            completionHandler(request)
            return
        }

        completionHandler(nil)
    }
}
