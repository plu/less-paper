import Foundation

// A permission codename is <action>_<type>, and the type may itself contain no separator -
// add_documenttype is one word. Splitting at the first underscore is therefore the whole rule.
//
// A Set because paperless repeats codenames: /api/ui_settings/ returns add_logentry,
// change_logentry, delete_logentry and view_logentry TWICE each (166 entries, 162 unique), so a
// plain array yields "add, add, change, change" for that one type - duplicate glyphs on screen,
// and duplicate ForEach ids, which SwiftUI warns about and renders undefined.
public struct PermissionSummary: Equatable, Sendable {

    public let actions: [String]

    public let type: String

    public static func grouped(_ permissions: [Permission]) -> [PermissionSummary] {
        var actionsByType: [String: Set<String>] = [:]

        for permission in permissions {
            let parts = permission.rawValue.split(separator: "_", maxSplits: 1)
            guard parts.count == 2 else {
                continue
            }
            actionsByType[String(parts[1]), default: []].insert(String(parts[0]))
        }

        return actionsByType
            .map { PermissionSummary(actions: $0.value.sorted(), type: $0.key) }
            .sorted { $0.type < $1.type }
    }
}
