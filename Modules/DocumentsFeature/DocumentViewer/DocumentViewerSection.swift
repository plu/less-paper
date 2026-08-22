import Foundation

public enum DocumentViewerSection: CaseIterable, Sendable {
    case content
    case metadata
    case notes
}

extension DocumentViewerSection {

    var localized: LocalizedStringResource {
        switch self {
        case .content:
            .content
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
        case .metadata:
            "info.circle"
        case .notes:
            "note.text"
        }
    }
}
