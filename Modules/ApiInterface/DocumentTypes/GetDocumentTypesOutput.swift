import Foundation
import Tagged

public typealias GetDocumentTypesOutput = ListOutput<DocumentType, DocumentType.Id>

public extension ListOutput where Element == DocumentType, Id == DocumentType.Id {

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
