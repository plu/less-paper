import Foundation
import Tagged

public typealias GetCorrespondentsOutput = ListOutput<Correspondent, Correspondent.Id>

public extension ListOutput where Element == Correspondent, Id == Correspondent.Id {

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
