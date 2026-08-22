import Foundation

public enum DocumentViewerSection: CaseIterable, Sendable {
    case content
    case notes
}

extension DocumentViewerSection {

    var localized: LocalizedStringResource {
        switch self {
        case .content:
            .content
        case .notes:
            .notes
        }
    }

    var systemImage: String {
        switch self {
        case .content:
            "text.alignleft"
        case .notes:
            "note.text"
        }
    }
}
