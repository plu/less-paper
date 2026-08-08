import Foundation
import Tagged

public typealias GetDocumentsOutput = ListOutput<Document, Document.Id>

public extension ListOutput where Element == Document, Id == Document.Id {

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
