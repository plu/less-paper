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
}
