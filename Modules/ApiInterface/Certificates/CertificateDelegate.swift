import AsyncAlgorithms
import Dependencies
import Foundation
import Security
import UIKit

public extension DependencyValues {
    var certificateDelegate: CertificateDelegate {
        get { self[CertificateDelegate.self] }
        set { self[CertificateDelegate.self] = newValue }
    }
}

extension CertificateDelegate: DependencyKey {
    public static let liveValue = CertificateDelegate()
}

public final class CertificateDelegate: NSObject, URLSessionTaskDelegate {
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
