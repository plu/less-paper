import Foundation

// String-backed rather than Int: the raw value is what a stored configuration carries, so it has to
// survive a case being added in the middle.
// One case per section of the row's Open menu rather than a single action carrying the section:
// this module cannot see DocumentsFeature's section type, and the raw value has to stay a flat
// string anyway.
public enum DocumentSwipeAction: String, CaseIterable, Codable, Equatable, Sendable {
    case clearInboxTags
    case delete
    case saveOffline
    case openContent
    case openCustomFields
    case openDetails
    case openHistory
    case openMetadata
    case openNotes
    case preview
    case share
}

public extension DocumentSwipeAction {

    // Clearing inbox tags is not among these. It is offered automatically, and only on a document
    // that actually has inbox tags, so putting it in Settings would ask the user to choose
    // something that is neither theirs to turn off nor meaningful on most rows.
    static let configurable = allCases.filter { $0 != .clearInboxTags }

    // Raw values from before a rename, still carried by stored configurations. `favorite` predates
    // Offline. `edit` opened the form on Details. The view- and edit- pairs split each section by
    // mode until the sheet started deciding the mode itself, so both halves land on the one
    // section. Translated rather than ignored: the settings decode compactMaps, so an unrecognised
    // value is dropped and the user's swipe stops existing rather than falling back to anything.
    init?(storedRawValue: String) {
        switch storedRawValue {
        case "edit", "editDetails":
            self = .openDetails
        case "editContent", "viewContent":
            self = .openContent
        case "editCustomFields", "viewCustomFields":
            self = .openCustomFields
        case "editNotes", "viewNotes":
            self = .openNotes
        case "favorite":
            self = .saveOffline
        case "viewHistory":
            self = .openHistory
        case "viewMetadata":
            self = .openMetadata
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
        case .openContent:
            .swipeActionOpenContent
        case .openCustomFields:
            .swipeActionOpenCustomFields
        case .openDetails:
            .swipeActionOpenDetails
        case .openHistory:
            .swipeActionOpenHistory
        case .openMetadata:
            .swipeActionOpenMetadata
        case .openNotes:
            .swipeActionOpenNotes
        case .preview:
            .swipeActionPreview
        case .saveOffline:
            .swipeActionOffline
        case .share:
            .swipeActionShare
        }
    }

    // Save offline's glyph is the unfilled one here because this names the action, not the state of
    // any one document. The swipe button swaps it for a document already saved.
    //
    // The Open glyphs repeat DocumentSheetSection's, which this module cannot import: a swipe
    // button shows only its glyph, so it has to be the one the Open menu shows beside the name.
    public var systemImage: String {
        switch self {
        case .clearInboxTags:
            "tray.and.arrow.down"
        case .delete:
            "trash"
        case .openContent:
            "text.alignleft"
        case .openCustomFields:
            "list.bullet.rectangle"
        case .openDetails:
            "square.and.pencil"
        case .openHistory:
            "clock.arrow.circlepath"
        case .openMetadata:
            "info.circle"
        case .openNotes:
            "note.text"
        case .preview:
            "eye"
        case .saveOffline:
            "arrow.down.circle"
        case .share:
            "square.and.arrow.up"
        }
    }

    // Exists so the full-swipe rule can be applied without the caller matching on the case.
    public var isDestructive: Bool {
        self == .delete
    }
}
