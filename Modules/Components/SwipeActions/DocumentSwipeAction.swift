import Foundation

// String-backed rather than Int: the raw value is what a stored configuration carries, so it has to
// survive a case being added in the middle.
// One case per section of the row's View and Edit menus rather than a single action carrying the
// section: this module cannot see DocumentsFeature's section types, and the raw value has to stay a
// flat string anyway.
public enum DocumentSwipeAction: String, CaseIterable, Codable, Equatable, Sendable {
    case clearInboxTags
    case delete
    case editContent
    case editCustomFields
    case editDetails
    case editNotes
    case saveOffline
    case preview
    case share
    case viewContent
    case viewCustomFields
    case viewHistory
    case viewMetadata
    case viewNotes
}

public extension DocumentSwipeAction {

    // Clearing inbox tags is not among these. It is offered automatically, and only on a document
    // that actually has inbox tags, so putting it in Settings would ask the user to choose
    // something that is neither theirs to turn off nor meaningful on most rows.
    static let configurable = allCases.filter { $0 != .clearInboxTags }

    // Raw values from before a rename, still carried by stored configurations: `favorite` predates
    // Offline, and `edit` and `openNotes` predate the per-section actions - each opened the form on
    // the section its successor names. Translated rather than ignored: the settings decode
    // compactMaps, so an unrecognised value is dropped and the user's swipe stops existing rather
    // than falling back to anything.
    init?(storedRawValue: String) {
        switch storedRawValue {
        case "edit":
            self = .editDetails
        case "favorite":
            self = .saveOffline
        case "openNotes":
            self = .editNotes
        default:
            self.init(rawValue: storedRawValue)
        }
    }
}

extension DocumentSwipeAction: Localizable {

    public var localized: LocalizedStringResource {
        switch self {
        case .clearInboxTags:
            .swipeActionClearInboxTags
        case .delete:
            .swipeActionDelete
        case .editContent:
            .swipeActionEditContent
        case .editCustomFields:
            .swipeActionEditCustomFields
        case .editDetails:
            .swipeActionEditDetails
        case .editNotes:
            .swipeActionEditNotes
        case .preview:
            .swipeActionPreview
        case .saveOffline:
            .swipeActionOffline
        case .share:
            .swipeActionShare
        case .viewContent:
            .swipeActionViewContent
        case .viewCustomFields:
            .swipeActionViewCustomFields
        case .viewHistory:
            .swipeActionViewHistory
        case .viewMetadata:
            .swipeActionViewMetadata
        case .viewNotes:
            .swipeActionViewNotes
        }
    }

    // Save offline's glyph is the unfilled one here because this names the action, not the state of
    // any one document. The swipe button swaps it for a document already saved.
    //
    // A swipe button shows only its glyph, so each Edit action needs one its View counterpart does
    // not share. The View glyphs are the ones the viewer's section menu uses.
    public var systemImage: String {
        switch self {
        case .clearInboxTags:
            "tray.and.arrow.down"
        case .delete:
            "trash"
        case .editContent:
            "pencil.line"
        case .editCustomFields:
            "rectangle.and.pencil.and.ellipsis"
        case .editDetails:
            "square.and.pencil"
        case .editNotes:
            "note.text.badge.plus"
        case .preview:
            "eye"
        case .saveOffline:
            "arrow.down.circle"
        case .share:
            "square.and.arrow.up"
        case .viewContent:
            "text.alignleft"
        case .viewCustomFields:
            "list.bullet.rectangle"
        case .viewHistory:
            "clock.arrow.circlepath"
        case .viewMetadata:
            "info.circle"
        case .viewNotes:
            "note.text"
        }
    }

    // Exists so the full-swipe rule can be applied without the caller matching on the case.
    public var isDestructive: Bool {
        self == .delete
    }
}
