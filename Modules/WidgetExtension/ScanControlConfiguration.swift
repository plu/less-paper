import ApiInterface
import AppIntents
import SwiftSharing

// Carries the server the user pinned when they placed the control, and nothing else. A
// ControlConfigurationIntent's result type is Never by definition, so it cannot be the action -
// the control's own OpenURLIntent is.
struct ScanControlConfiguration: ControlConfigurationIntent {

    // Not `.scanControlTitle`: the ExtractAppIntentsMetadata build step statically parses
    // `static var title` and requires a literal or a direct `LocalizedStringResource` initializer
    // call, not a catalog-generated static member access.
    static let title = LocalizedStringResource("scanControlTitle")

    @Parameter(title: LocalizedStringResource("scanControlServerParameter"))
    var server: ServerEntity?

    init() {
        @Shared(.selectedServer)
        var selectedServer

        self.server = selectedServer.map(ServerEntity.init)
    }
}
