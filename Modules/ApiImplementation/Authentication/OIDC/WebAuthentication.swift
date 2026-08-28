import ApiInterface
import AuthenticationServices
import Dependencies
import DependenciesMacros
import Foundation
import UIKit

/// The one step of the login that leaves the app.
///
/// Behind a dependency so the rest of the flow can be tested without a browser: every other step is
/// HTTP and can be stubbed, and this would otherwise make the whole sequence untestable.
@DependencyClient
struct WebAuthentication: Sendable {

    /// Returns the callback URL the provider redirected to, or throws `OIDCError.cancelled` if the
    /// user dismissed the browser.
    var authenticate: @Sendable (
        _ url: URL,
        _ callbackScheme: String
    ) async throws -> URL
}

extension WebAuthentication: TestDependencyKey {

    static let previewValue = Self(
        authenticate: { _, _ in URL(string: "atlp://oidc-callback?code=c0ff33&state=state")! }
    )

    static let testValue = Self()
}

extension WebAuthentication: DependencyKey {

    static let liveValue = Self(
        authenticate: { url, callbackScheme in
            try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let session = ASWebAuthenticationSession(
                        url: url,
                        callbackURLScheme: callbackScheme
                    ) { callback, error in
                        if let callback {
                            continuation.resume(returning: callback)
                            return
                        }

                        // Dismissing the browser is a decision, not a failure, and reporting it as
                        // one would put an error in front of someone who just changed their mind.
                        let isCancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                        continuation.resume(
                            throwing: isCancelled ? OIDCError.cancelled : (error ?? OIDCError.missingCode)
                        )
                    }

                    // The provider decides whether a previous session is reused; asking for an
                    // ephemeral one means a second account can be used without clearing Safari.
                    session.prefersEphemeralWebBrowserSession = true
                    session.presentationContextProvider = WebAuthenticationPresenter.shared
                    session.start()
                }
            }
        }
    )
}

/// `ASWebAuthenticationSession` will not start without somewhere to present from.
@MainActor
private final class WebAuthenticationPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {

    static let shared = WebAuthenticationPresenter()

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}

extension DependencyValues {

    var webAuthentication: WebAuthentication {
        get { self[WebAuthentication.self] }
        set { self[WebAuthentication.self] = newValue }
    }
}
