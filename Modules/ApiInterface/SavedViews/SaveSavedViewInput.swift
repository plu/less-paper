import Foundation
import Tagged

public struct SaveSavedViewInput: Codable, Equatable, Sendable {

    public var filterRules: [FilterRule]

    public var name: String

    public var owner: Clearable<User.Id>?

    public var setPermissions: Permissions?

    public var sortField: SortField

    public var sortReverse: Bool

    public init(
        filterRules: [FilterRule] = [],
        name: String,
        owner: Clearable<User.Id>? = nil,
        setPermissions: Permissions? = nil,
        sortField: SortField = .added,
        sortReverse: Bool = true
    ) {
        self.filterRules = filterRules
        self.name = name
        self.owner = owner
        self.setPermissions = setPermissions
        self.sortField = sortField
        self.sortReverse = sortReverse
    }
}

public extension SaveSavedViewInput {

    init(
        setPermissions: Permissions? = nil,
        savedView: SavedView?
    ) {
        self.init(
            filterRules: savedView?.filterRules ?? [],
            name: savedView?.name ?? "",
            owner: savedView?.owner.ifPresent { .value($0) },
            setPermissions: setPermissions,
            sortField: savedView?.sortField ?? .created,
            sortReverse: savedView?.sortDirection.sortReverse ?? true
        )
    }
}

public extension SaveSavedViewInput {

    static func testValue(
        filterRules: [FilterRule] = [],
        name: String = "Test SavedView",
        owner: Clearable<User.Id>? = .value(1),
        setPermissions: Permissions = .testValue(),
        sortField: SortField = .added,
        sortReverse: Bool = true
    ) -> Self {
        .init(
            filterRules: filterRules,
            name: name,
            owner: owner,
            setPermissions: setPermissions,
            sortField: sortField,
            sortReverse: sortReverse
        )
    }
}
