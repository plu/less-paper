import Foundation

public struct GetDocumentsByIdsInput: Codable, Equatable, Sendable {

    public let ids: [Document.Id]

    public init(
        ids: [Document.Id]
    ) {
        self.ids = ids
    }
}

public extension GetDocumentsByIdsInput {

    static func testValue(
        ids: [Document.Id] = []
    ) -> Self {
        .init(
            ids: ids
        )
    }
}
