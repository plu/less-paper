import Foundation

public enum MarketingScreen: String, CaseIterable, Sendable {
    case inbox
    case documents
    case search
    case tags
    case view
    case edit
    case settings

    // Matches the names the capture writes, so the numbering that orders them on the store survives
    // the trip through the renderer.
    public var fileStem: String {
        switch self {
        case .inbox:
            "01-Inbox"
        case .documents:
            "02-Documents"
        case .search:
            "03-Search"
        case .tags:
            "04-Tags"
        case .view:
            "05-View"
        case .edit:
            "06-Edit"
        case .settings:
            "07-Settings"
        }
    }

    // From the shared string catalog rather than one of this module's own: Module+Targets attaches
    // Shared/Framework/Resources to every framework and nothing else, so a catalog kept here would
    // never be bundled.
    public var caption: LocalizedStringResource {
        switch self {
        case .inbox:
            .marketingInbox
        case .documents:
            .marketingDocuments
        case .search:
            .marketingSearch
        case .tags:
            .marketingTags
        case .view:
            .marketingView
        case .edit:
            .marketingEdit
        case .settings:
            .marketingSettings
        }
    }
}
