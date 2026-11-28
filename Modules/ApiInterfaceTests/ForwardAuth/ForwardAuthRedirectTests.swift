import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct ForwardAuthRedirectTests {

    @Test
    func signInURL_isTheServersUISettingsEndpoint() {
        let redirect = ForwardAuthRedirect.testValue(
            server: .testValue(url: URL(string: "https://paperless.example.com")!)
        )

        #expect(redirect.signInURL == URL(string: "https://paperless.example.com/api/ui_settings/")!)
    }

    @Test
    func signInURL_keepsThePathPaperlessIsServedUnder() {
        let redirect = ForwardAuthRedirect.testValue(
            server: .testValue(url: URL(string: "https://example.com/paperless")!)
        )

        #expect(redirect.signInURL == URL(string: "https://example.com/paperless/api/ui_settings/")!)
    }

    @Test(arguments: [200, 401, 403])
    func isSignInComplete_trueForAnyAnswerAtTheSignInURL(statusCode: Int) {
        let redirect = ForwardAuthRedirect.testValue(
            server: .testValue(url: URL(string: "https://paperless.example.com:8300")!)
        )

        #expect(redirect.isSignInComplete(response(
            "https://paperless.example.com:8300/api/ui_settings/",
            statusCode: statusCode
        )))
    }

    // mod_auth_openidc answers a callback it rejects from the paperless host. Counting that as a
    // finished login closed the sheet, replayed into a fresh bounce, and looped until the proxy
    // ran out of state cookies and answered 503.
    @Test
    func isSignInComplete_falseForTheProxysOwnCallbackOnTheServerHost() {
        let redirect = ForwardAuthRedirect.testValue(
            server: .testValue(url: URL(string: "https://paperless.example.com:8300")!)
        )

        #expect(!redirect.isSignInComplete(response(
            "https://paperless.example.com:8300/oidc/redirect?state=abc",
            statusCode: 400
        )))
    }

    // The web view's first response is the proxy bouncing signInURL itself.
    @Test
    func isSignInComplete_falseForTheProxysBounceAtTheSignInURL() {
        let redirect = ForwardAuthRedirect.testValue(
            server: .testValue(url: URL(string: "https://paperless.example.com:8300")!)
        )

        #expect(!redirect.isSignInComplete(response(
            "https://paperless.example.com:8300/api/ui_settings/",
            statusCode: 302
        )))
    }

    // The proxy, or paperless behind it, failing at signInURL. Closing the sheet on it replays
    // every parked request into the same failure.
    @Test(arguments: [500, 502, 503])
    func isSignInComplete_falseForAServerErrorAtTheSignInURL(statusCode: Int) {
        let redirect = ForwardAuthRedirect.testValue(
            server: .testValue(url: URL(string: "https://paperless.example.com:8300")!)
        )

        #expect(!redirect.isSignInComplete(response(
            "https://paperless.example.com:8300/api/ui_settings/",
            statusCode: statusCode
        )))
    }

    @Test
    func isSignInComplete_falseForTheLoginHost() {
        let redirect = ForwardAuthRedirect.testValue(
            server: .testValue(url: URL(string: "https://paperless.example.com:8300")!)
        )

        #expect(!redirect.isSignInComplete(response(
            "https://auth.example.com:8300/api/ui_settings/",
            statusCode: 200
        )))
    }

    private func response(_ url: String, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: url)!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
