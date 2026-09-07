import ApiInterface
import AppIntents
import SwiftUI
import WidgetKit

struct ScanControl: ControlWidget {

    static let kind = "com.aptumtek.app.Paperless.ScanControl"

    // Not `.scanControlTitle` / `.scanControlDescription`: the ExtractAppIntentsMetadata build step
    // statically parses `.displayName` / `.description` and requires a literal or a direct
    // `LocalizedStringResource` initializer call, not a catalog-generated static member access.
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ScanControlConfiguration.self
        ) { configuration in
            // No server selected is not an error: `appLaunchURL` is a link `DeepLink(url:)` cannot
            // parse, so the app just opens plainly and the user lands on the server list.
            let scanURL = DeepLink.scanURL(server: configuration.server?.server) ?? DeepLink.appLaunchURL

            // Labelled with the server the control is pinned to, so two controls for two servers
            // are told apart in Control Center without opening either.
            ControlWidgetButton(action: OpenURLIntent(scanURL)) {
                Label(
                    configuration.server?.alias ?? String(localized: LocalizedStringResource("scanControlTitle")),
                    systemImage: "doc.viewfinder"
                )
            }
        }
        .displayName(LocalizedStringResource("scanControlTitle"))
        .description(LocalizedStringResource("scanControlDescription"))
    }
}
