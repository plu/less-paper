import SwiftUI
import WidgetKit

struct ScanControl: ControlWidget {

    static let kind = "com.aptumtek.app.Paperless.ScanControl"

    // Not on `.displayName` / `.description` below: the ExtractAppIntentsMetadata build step
    // statically parses those modifiers and requires a literal or a direct `LocalizedStringResource`
    // initializer call, not a catalog-generated static member access. The Label inside the button
    // is ordinary runtime code, so it uses the generated symbol like everywhere else.
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ScanControlConfiguration.self
        ) { configuration in
            // Labelled with the server the control is pinned to, so two controls for two servers
            // are told apart in Control Center without opening either.
            ControlWidgetButton(action: ScanIntent(server: configuration.server)) {
                Label(
                    configuration.server?.alias ?? String(localized: .scanControlTitle),
                    systemImage: "doc.viewfinder"
                )
            }
        }
        .displayName(LocalizedStringResource("scanControlTitle"))
        .description(LocalizedStringResource("scanControlDescription"))
    }
}
