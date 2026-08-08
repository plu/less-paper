import Foundation
import Tagged

public typealias GetAllDocumentIdsOutput = ListOutput<DocumentId, Document.Id>

public struct DocumentId: Codable, Equatable, Hashable, Identifiable, Sendable {

    public typealias Id = Tagged<Document, Int>

    public let id: Id

    public init(id: Id) {
        self.id = id
    }
}

public extension ListOutput where Element == DocumentId, Id == Document.Id {
    static func testValue(
        count: Int = 0,
        next: URL? = nil,
        results: [Element] = []
    ) -> Self {
        .init(
            count: count,
            next: next,
            results: results
        )
    }
}
