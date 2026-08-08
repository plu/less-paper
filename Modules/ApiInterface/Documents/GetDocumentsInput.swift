import Foundation

public struct GetDocumentsInput: Codable, Equatable, Sendable {
    public let filterRules: [FilterRule]
    public let sortDirection: SortDirection
    public let sortField: SortField

    public let url: URL?

    public init(
        filterRules: [FilterRule] = [],
        sortDirection: SortDirection = .descending,
        sortField: SortField = .created,
        url: URL? = nil
    ) {
        self.filterRules = filterRules
        self.sortField = sortField
        self.sortDirection = sortDirection
        self.url = url
    }
}

public extension GetDocumentsInput {

    static func testValue(
        filterRules: [FilterRule] = [],
        sortDirection: SortDirection = .descending,
        sortField: SortField = .created,
        url: URL? = nil
    ) -> Self {
        .init(
            filterRules: filterRules,
            sortDirection: sortDirection,
            sortField: sortField,
            url: url
        )
    }
}
