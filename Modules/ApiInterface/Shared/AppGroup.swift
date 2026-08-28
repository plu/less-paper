import Foundation

public enum AppGroup {

    // The cookie store the API session writes and the login web view reads must name the same
    // group, or a share is asked to sign in again while the app's session is live. Entitled for
    // .app, .shareApp and .shareExtension in Module.swift.
    public static let identifier = "group.com.plunien.app.Paperless"

    public static var cookieStorage: HTTPCookieStorage {
        HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: identifier)
    }
}
