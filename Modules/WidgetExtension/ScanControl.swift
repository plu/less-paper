import ApiInterface
import AppIntents
import SwiftSharing
import SwiftUI
import WidgetKit

struct ScanControl: ControlWidget {

    static let kind = "com.aptumtek.app.Paperless.ScanControl"

    // Not `.scanControlTitle` / `.scanControlDescription`: the ExtractAppIntentsMetadata build step
    // statically parses `.displayName` / `.description` and requires a literal or a direct
    // `LocalizedStringResource` initializer call, not a catalog-generated static member access.
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            @Shared(.selectedServer)
            var selectedServer

            // No server selected is not an error: `appLaunchURL` is a link `DeepLink(url:)` cannot
            // parse, so the app just opens plainly and the user lands on the server list.
            let scanURL = DeepLink.scanURL(server: selectedServer) ?? DeepLink.appLaunchURL

            ControlWidgetButton(action: OpenURLIntent(scanURL)) {
                Label(String(localized: LocalizedStringResource("scanControlTitle")), systemImage: "doc.viewfinder")
            }
        }
        .displayName(LocalizedStringResource("scanControlTitle"))
        .description(LocalizedStringResource("scanControlDescription"))
    }
}
