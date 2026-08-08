import Foundation

public struct GetAllDocumentIdsInput: Codable, Equatable, Sendable {
    public let filterRules: [FilterRule]

    public init(
        filterRules: [FilterRule] = []
    ) {
        self.filterRules = filterRules
    }
}

public extension GetAllDocumentIdsInput {
    static func testValue(
        filterRules: [FilterRule] = []
    ) -> Self {
        .init(
            filterRules: filterRules
        )
    }
}
