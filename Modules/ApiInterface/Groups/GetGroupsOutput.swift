import Foundation
import Tagged

public typealias GetGroupsOutput = ListOutput<Group, Group.Id>

public extension ListOutput where Element == Group, Id == Group.Id {

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
