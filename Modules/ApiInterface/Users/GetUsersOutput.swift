import Foundation
import Tagged

public typealias GetUsersOutput = ListOutput<User, User.Id>

public extension ListOutput where Element == User, Id == User.Id {

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
