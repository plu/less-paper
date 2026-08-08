import Foundation
import Tagged

public typealias GetSavedViewsOutput = ListOutput<SavedView, SavedView.Id>

public extension ListOutput where Element == SavedView, Id == SavedView.Id {

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
