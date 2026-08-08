import Foundation
import Tagged

public typealias GetStoragePathsOutput = ListOutput<StoragePath, StoragePath.Id>

public extension ListOutput where Element == StoragePath, Id == StoragePath.Id {

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
