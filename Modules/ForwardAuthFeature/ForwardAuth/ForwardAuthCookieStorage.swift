import ApiInterface
import Foundation

// Wraps the app-group cookie storage the API session uses. Extracted so the read and write
// can be tested without spinning up a WKWebView.
enum ForwardAuthCookieStorage {

    static var appGroup: HTTPCookieStorage {
        AppGroup.cookieStorage
    }

    // Cookies to hand to a freshly opened WKWebView so a still-valid session does not force a
    // pointless re-login.
    static func cookiesToSeed() -> [HTTPCookie] {
        appGroup.cookies ?? []
    }

    // Called with cookies read from WKWebView after a response from the server's host arrives.
    // The API session picks these up on its next request.
    static func store(_ cookies: [HTTPCookie]) {
        for cookie in cookies {
            appGroup.setCookie(cookie)
        }
    }
}
