import Foundation

// String-backed rather than Int: the raw value is what a stored configuration carries, so it has to
// survive a case being added in the middle.
public enum DocumentSwipeAction: String, CaseIterable, Codable, Equatable, Sendable {
    case clearInboxTags
    case delete
    case edit
    case favorite
    case openNotes
    case preview
    case share
}

public extension DocumentSwipeAction {

    // Clearing inbox tags is not among these. It is offered automatically, and only on a document
    // that actually has inbox tags, so putting it in Settings would ask the user to choose
    // something that is neither theirs to turn off nor meaningful on most rows.
    static let configurable = allCases.filter { $0 != .clearInboxTags }
}

extension DocumentSwipeAction: Localizable {

    public var localized: LocalizedStringResource {
        switch self {
        case .clearInboxTags:
            .swipeActionClearInboxTags
        case .delete:
            .swipeActionDelete
        case .edit:
            .swipeActionEdit
        case .favorite:
            .swipeActionFavorite
        case .openNotes:
            .swipeActionOpenNotes
        case .preview:
            .swipeActionPreview
        case .share:
            .swipeActionShare
        }
    }

    // Favorite's glyph is the unfilled one here because this names the action, not the state of any
    // one document. The swipe button swaps it for a document already favorited.
    public var systemImage: String {
        switch self {
        case .clearInboxTags:
            "tray.and.arrow.down"
        case .delete:
            "trash"
        case .edit:
            "square.and.pencil"
        case .favorite:
            "heart"
        case .openNotes:
            "note.text"
        case .preview:
            "eye"
        case .share:
            "square.and.arrow.up"
        }
    }

    // Exists so the full-swipe rule can be applied without the caller matching on the case.
    public var isDestructive: Bool {
        self == .delete
    }
}
