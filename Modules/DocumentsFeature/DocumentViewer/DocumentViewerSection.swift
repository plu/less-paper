import Foundation

public enum DocumentViewerSection: CaseIterable, Sendable {
    case content
    case customFields
    case history
    case metadata
    case notes
}

extension DocumentViewerSection {

    var localized: LocalizedStringResource {
        switch self {
        case .content:
            .content
        case .customFields:
            .customFields
        case .history:
            .history
        case .metadata:
            .metadata
        case .notes:
            .notes
        }
    }

    var systemImage: String {
        switch self {
        case .content:
            "text.alignleft"
        case .customFields:
            "list.bullet.rectangle"
        case .history:
            "clock.arrow.circlepath"
        case .metadata:
            "info.circle"
        case .notes:
            "note.text"
        }
    }
}

extension DocumentViewerSection {

    // The one place a section is dropped for lack of permission. Three menus open this sheet — the
    // detail toolbar, the row's context menu and the sheet's own picker — and each copy of the
    // filter was one more place to forget a new section.
    static func visible(canViewHistory: Bool, canViewNotes: Bool) -> [Self] {
        allCases.filter { section in
            switch section {
            case .content, .customFields, .metadata:
                true
            case .history:
                canViewHistory
            case .notes:
                canViewNotes
            }
        }
    }
}
