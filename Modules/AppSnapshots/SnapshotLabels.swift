import Foundation

// The labels the capture navigates by, per language.
//
// The capture matches on visible labels, which differ per language, so they are listed rather than
// hardcoded in English. Accessibility identifiers on the views would avoid the table entirely and
// would be the right answer for a test that asserts behaviour - see AGENTS.md. This is not that:
// nothing here checks the app is correct, it only has to reach a screen, and keeping the change
// inside the capture target leaves the app and its UI tests untouched.
//
// Copied from Shared/Framework/Resources/Localizable.xcstrings. A changed string breaks a
// screenshot, not the app.
struct SnapshotLabels {

    static func current(_ language: String) -> Self {
        language.hasPrefix("de") ? .german : .english
    }

    static let english = Self(
        documents: "Documents",
        edit: "Edit",
        editDocument: "Edit document",
        favorites: "Favorites",
        filter: "Filter",
        inbox: "Inbox",
        notAssigned: "Not assigned",
        servers: "Servers",
        settings: "Settings",
        tag: "Tag",
        titleAndContent: "Title & content"
    )

    static let german = Self(
        documents: "Dokumente",
        edit: "Bearbeiten",
        editDocument: "Dokument bearbeiten",
        favorites: "Favoriten",
        filter: "Filter",
        inbox: "Eingang",
        notAssigned: "Nicht zugewiesen",
        servers: "Server",
        settings: "Einstellungen",
        tag: "Tag",
        titleAndContent: "Titel & Inhalt"
    )

    let documents: String
    let edit: String
    let editDocument: String
    let favorites: String
    let filter: String
    let inbox: String
    let notAssigned: String
    let servers: String
    let settings: String
    let tag: String
    let titleAndContent: String
}
