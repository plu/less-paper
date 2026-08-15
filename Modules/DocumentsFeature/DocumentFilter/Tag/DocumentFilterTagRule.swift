import Foundation

public enum DocumentFilterTagRule: String, CaseIterable, Equatable, Sendable {
    /// Has all of the selected tags, and none of the excluded ones.
    case all
    /// Has at least one of the selected tags.
    case any
    /// Has at least one tag, whichever it is — Paperless's `is_tagged=1`.
    case assigned
    /// Has no tags at all — Paperless's `is_tagged=0`.
    case notAssigned

    /// Whether the rule filters on tag membership alone, without a selection.
    var isTagged: Bool? {
        switch self {
        case .all, .any:
            nil
        case .assigned:
            true
        case .notAssigned:
            false
        }
    }

    var localized: LocalizedStringResource {
        switch self {
        case .all:
            .all
        case .any:
            .any
        case .assigned:
            .assigned
        case .notAssigned:
            .notAssigned
        }
    }
}
