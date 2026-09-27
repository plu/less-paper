import Foundation

public enum DocumentSheetSection: CaseIterable, Sendable {
    case content
    case customFields
    case details
    case history
    case metadata
    case notes
}

extension DocumentSheetSection {

    var localized: LocalizedStringResource {
        switch self {
        case .content:
            .content
        case .customFields:
            .customFields
        case .details:
            .details
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
        case .details:
            "square.and.pencil"
        case .history:
            "clock.arrow.circlepath"
        case .metadata:
            "info.circle"
        case .notes:
            "note.text"
        }
    }
}

extension DocumentSheetSection {

    // The one place a section is dropped. Three menus open this sheet — the detail toolbar, the
    // row's context menu and the sheet's own picker — plus the swipe actions, and each copy of the
    // filter was one more place to forget a new section.
    //
    // Details is the only section with nothing to show read-only: it exists to change the fields,
    // and the detail screen already names the document they describe. Notes and History answer 403
    // without their permissions.
    static func visible(isEditable: Bool, canViewHistory: Bool, canViewNotes: Bool) -> [Self] {
        allCases.filter { section in
            switch section {
            case .content, .customFields, .metadata:
                true
            case .details:
                isEditable
            case .history:
                canViewHistory
            case .notes:
                canViewNotes
            }
        }
    }
}
