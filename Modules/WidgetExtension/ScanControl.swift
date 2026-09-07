import AppIntents
import SwiftUI
import WidgetKit

struct ScanControl: ControlWidget {

    static let kind = "com.aptumtek.app.Paperless.ScanControl"

    // Not `.scanControlTitle` / `.scanControlDescription`: the ExtractAppIntentsMetadata build step
    // statically parses `.displayName` / `.description` and requires a literal or a direct
    // `LocalizedStringResource` initializer call, not a catalog-generated static member access.
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ScanIntent()) {
                Label(String(localized: LocalizedStringResource("scanControlTitle")), systemImage: "doc.viewfinder")
            }
        }
        .displayName(LocalizedStringResource("scanControlTitle"))
        .description(LocalizedStringResource("scanControlDescription"))
    }
}
