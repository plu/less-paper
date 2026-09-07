import ApiInterface
import AppIntents
import Foundation
import SwiftSharing
import SwiftUI

struct ScanIntent: AppIntent {

    // Not `.scanControlTitle`: the ExtractAppIntentsMetadata build step statically parses this
    // declaration and requires a literal or a direct `LocalizedStringResource` initializer call, not
    // a catalog-generated static member access, or the build fails with "'LocalizedStringResource'
    // must be initialized with a call to its initializer or a string literal".
    static let title: LocalizedStringResource = .init("scanControlTitle")

    // The scanner is a view controller that has to run in the app, so every path here ends in the
    // app being opened. The URL only decides which server it opens on, and having none is not an
    // error: the app opens plainly and the user lands on the server list.
    static let openAppWhenRun = true

    // The brief's original body returned `.result()` from one branch and
    // `.result(opensIntent: OpenURLIntent(url))` from the other. Under this project's iOS 18.0
    // deployment target that does not compile: the only always-available `result(opensIntent:)`
    // overload is a generic, `@_disfavoredOverload` one that bakes the intent's concrete type into
    // the return value (`IntentResultContainer<Never, OpenURLIntent, Never, Never>`), which is not
    // the same underlying type as plain `.result()` (`IntentResultContainer<Never, Never, Never,
    // Never>`) - the overload that would make them match needs iOS 18.2. Driving the open through
    // the environment's `OpenURLAction` instead keeps every return statement identical and is also
    // the workaround Apple's own DTS staff gives for `OpenURLIntent` not reliably honoring a custom
    // URL scheme (ours is `lesspaper://`, not a universal link) before iOS 18.1.
    func perform() async throws -> some IntentResult {
        @Shared(.selectedServer)
        var selectedServer

        if let url = DeepLink.scanURL(server: selectedServer) {
            // `EnvironmentValues` is not `Sendable`, so it has to be both built and used inside the
            // same main-actor hop; constructing it here and sending it into `.openURL` separately is
            // what Swift 6 strict concurrency rejects.
            await MainActor.run {
                EnvironmentValues().openURL(url)
            }
        }

        return .result()
    }
}
