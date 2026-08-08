import Foundation

public enum SortDirection: String, CaseIterable, Codable, Sendable {
    case ascending = ""
    case descending = "-"
}

public extension SortDirection {
    var sortReverse: Bool {
        self == .descending
    }
}
