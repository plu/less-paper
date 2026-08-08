import Dependencies
import Foundation
import Tagged

public struct Group: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<Group, Int>

    public let id: Group.Id

    public let name: String

    @SkipUnknownValues
    public var permissions: [Permission]

    public init(
        id: Group.Id,
        name: String,
        permissions: [Permission]
    ) {
        self.id = id
        self.name = name
        self.permissions = permissions
    }
}

extension Group: Comparable {
    public static func < (lhs: Group, rhs: Group) -> Bool {
        lhs.name < rhs.name
    }
}

extension Group: CustomStringConvertible {
    public var description: String {
        name
    }
}

public extension Group {

    static func testValue(
        id: Group.Id = 1,
        name: String = "Admins",
        permissions: [Permission] = Permission.allCases
    ) -> Self {
        .init(
            id: id,
            name: name,
            permissions: permissions
        )
    }
}

public extension Group.Id {

    func get(_ server: Server) -> Group? {
        @Dependency(\.apiCache)
        var apiCache

        return apiCache.group(id: self, server: server)
    }
}
