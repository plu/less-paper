import ApiInterface
import Dependencies
import SwiftUI
import WebKit

struct ForwardAuthWebView: UIViewRepresentable {

    let redirect: ForwardAuthRedirect

    let onFinished: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        Task { @MainActor in
            // Seed cookies from app-group storage before the first load. A live session in the
            // app authenticates the login host without a second sign-in - matters for expiry:
            // the user is already signed in with the identity provider, just not with this
            // particular WKWebView instance.
            let store = webView.configuration.websiteDataStore.httpCookieStore
            for cookie in ForwardAuthCookieStorage.cookiesToSeed() {
                await store.setCookie(cookie)
            }
            webView.load(URLRequest(url: redirect.url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {

        let parent: ForwardAuthWebView

        init(_ parent: ForwardAuthWebView) {
            self.parent = parent
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse
        ) async -> WKNavigationResponsePolicy {
            guard let response = navigationResponse.response as? HTTPURLResponse,
                  response.url?.host() == parent.redirect.server.url.host()
            else {
                return .allow
            }

            // A response has come back from the server's host - the cookies WKWebView now holds
            // are what the API session needs. Copy them to app-group storage, then let the
            // outer view close the sheet.
            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            ForwardAuthCookieStorage.store(cookies)

            parent.onFinished()

            return .allow
        }

        // Route certificate challenges through certificateApprovalChannel like everything else.
        // Both prior attempts returned .useCredential for any serverTrust presented - a
        // self-signed proxy is exactly the deployment this feature targets, and trusting every
        // certificate at the one moment credentials are being typed is the hole the approval
        // flow closes.
        @MainActor
        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            await withCheckedContinuation { continuation in
                Task {
                    @Dependency(\.certificateApprovalChannel)
                    var channel

                    let request = CertificateApprovalRequest(
                        challenge: challenge,
                        completion: { disposition, credential in
                            continuation.resume(returning: (disposition, credential))
                        },
                        url: webView.url
                    )

                    await channel.send(.request(request))
                }
            }
        }
    }
}
