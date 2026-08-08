import Foundation
import Tagged

public typealias GetTagsOutput = ListOutput<Tag, Tag.Id>

public extension ListOutput where Element == Tag, Id == Tag.Id {

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
