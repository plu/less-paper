#if DEBUG
import Foundation

// German names for the catalogue entries the screenshots show.
//
// The fixtures are the seeded instance verbatim, and that instance is in English. Left alone, the
// German screenshots would show German documents filed under "Tax Return" and "Archive", which
// reads half finished. Renaming here rather than in the fixtures keeps them equal to the server and
// puts the choice of what German users see beside the choice of which documents they see.
//
// Correspondents are untouched: Stadtwerke München and Deutsche Telekom are names, not words.
extension SnapshotConfiguration.Corpus {

    func localized(_ name: String) -> String {
        switch self {
        case .english:
            name
        case .german:
            Self.germanNames[name] ?? name
        }
    }

    private static let germanNames = [
        // Tags
        "Audio": "Audio",
        "Furniture": "Möbel",
        "Important": "Wichtig",
        "Inbox": "Eingang",
        "Kids": "Kinder",
        "Locked": "Gesperrt",
        "Manual": "Anleitung",
        "Needs Review": "Zu prüfen",
        "Tax": "Steuer",
        "Toys": "Spielzeug",
        "Warranty": "Garantie",
        // Document types
        "Assembly Instructions": "Aufbauanleitung",
        "Bank Statement": "Kontoauszug",
        "Invoice": "Rechnung",
        "Tax Form": "Steuerformular",
        "Tax Return": "Steuererklärung",
        // Storage paths
        "Archive": "Archiv",
        "Manuals": "Anleitungen",
        "Taxes": "Steuern"
    ]
}
#endif
