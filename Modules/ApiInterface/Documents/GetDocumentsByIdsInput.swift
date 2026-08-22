import Foundation

public struct GetDocumentsByIdsInput: Codable, Equatable, Sendable {

    public let ids: [Document.Id]

    public let sortDirection: SortDirection?

    public let sortField: SortField?

    public init(
        ids: [Document.Id],
        sortDirection: SortDirection? = nil,
        sortField: SortField? = nil
    ) {
        self.ids = ids
        self.sortDirection = sortDirection
        self.sortField = sortField
    }
}

public extension GetDocumentsByIdsInput {

    static func testValue(
        ids: [Document.Id] = [],
        sortDirection: SortDirection? = nil,
        sortField: SortField? = nil
    ) -> Self {
        .init(
            ids: ids,
            sortDirection: sortDirection,
            sortField: sortField
        )
    }
}
