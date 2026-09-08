import ApiInterface
import AppIntents
import Foundation

// The control's action. OpenURLIntent cannot be the button's action itself: its PerformResult is
// Never, so there is no body for AppIntents to run, and a tap does nothing at all. It is meant to
// be returned from another intent's perform(), which is what this type exists to do.
struct ScanIntent: AppIntent {

    static let title = LocalizedStringResource("scanControlTitle")

    // The scanner is a view controller that has to run in the app, so every path here ends in the
    // app being opened.
    static let openAppWhenRun = true

    @Parameter(title: LocalizedStringResource("scanControlServerParameter"))
    var server: ServerEntity?

    // One return statement, deliberately. Returning `.result()` on one branch and
    // `.result(opensIntent:)` on the other does not compile at an iOS 18.0 deployment target - the
    // overload reconciling their two container types needs 18.2 - and `appLaunchURL` removes the
    // need for a second branch by giving the no-server case a URL of its own.
    func perform() async throws -> some IntentResult {
        .result(opensIntent: OpenURLIntent(
            DeepLink.scanURL(server: server?.server) ?? DeepLink.appLaunchURL
        ))
    }

    init() {}

    init(server: ServerEntity?) {
        self.server = server
    }
}
