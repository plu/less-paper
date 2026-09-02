import Foundation
import Tagged

public struct SavedView: Codable, Equatable, Identifiable, Sendable {
    public typealias Id = Tagged<SavedView, Int>

    public let filterRules: [FilterRule]

    public let id: Id

    public let name: String

    public let owner: User.Id?

    public var showInSidebar = false

    public var showOnDashboard = false

    public let sortDirection: SortDirection

    public let sortField: SortField

    public let userCanChange: Bool

    public init(
        filterRules: [FilterRule],
        id: Id,
        name: String,
        owner: User.Id?,
        showInSidebar: Bool = false,
        showOnDashboard: Bool = false,
        sortDirection: SortDirection,
        sortField: SortField,
        userCanChange: Bool
    ) {
        self.filterRules = filterRules
        self.id = id
        self.name = name
        self.owner = owner
        self.showInSidebar = showInSidebar
        self.showOnDashboard = showOnDashboard
        self.sortDirection = sortDirection
        self.sortField = sortField
        self.userCanChange = userCanChange
    }
}

public extension SavedView {

    private enum CodingKeys: String, CodingKey {
        case filterRules, id, name, owner, showInSidebar, showOnDashboard, sortReverse, sortField, userCanChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A rule type from a newer paperless than this app knows about would otherwise fail the
        // whole decode, and with it the cache update that adding a server runs - the app cannot
        // be reached at all to report it. The dropped rule widens what the view matches, which
        // is at least visible. Note it is dropped on write too, so saving such a view here
        // removes the rule on the server.
        filterRules = try container.decode([MaybeDecodable<FilterRule>].self, forKey: .filterRules)
            .compactMap(\.wrapped)
        id = try container.decode(Id.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        owner = try container.decodeIfPresent(User.Id.self, forKey: .owner)
        showInSidebar = try container.decodeIfPresent(Bool.self, forKey: .showInSidebar) ?? false
        showOnDashboard = try container.decodeIfPresent(Bool.self, forKey: .showOnDashboard) ?? false
        // paperless-ngx stores sort_field as nullable, so a view saved without one arrives as
        // null - the same fallback the enum already applies to a field name it does not know.
        sortField = try container.decodeIfPresent(SortField.self, forKey: .sortField) ?? .created
        sortDirection = try container.decode(Bool.self, forKey: .sortReverse) ? .descending : .ascending
        userCanChange = try container.decode(Bool.self, forKey: .userCanChange)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filterRules, forKey: .filterRules)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(owner, forKey: .owner)
        try container.encode(showInSidebar, forKey: .showInSidebar)
        try container.encode(showOnDashboard, forKey: .showOnDashboard)
        try container.encode(sortField, forKey: .sortField)
        try container.encode(sortDirection.sortReverse, forKey: .sortReverse)
        try container.encode(userCanChange, forKey: .userCanChange)
    }
}

public extension SavedView {

    static func testValue(
        filterRules: [FilterRule] = [],
        id: Id = 1,
        name: String = "Test SavedView",
        owner: User.Id? = 3,
        showInSidebar: Bool = false,
        showOnDashboard: Bool = false,
        sortDirection: SortDirection = .descending,
        sortField: SortField = .added,
        userCanChange: Bool = true
    ) -> Self {
        .init(
            filterRules: filterRules,
            id: id,
            name: name,
            owner: owner,
            showInSidebar: showInSidebar,
            showOnDashboard: showOnDashboard,
            sortDirection: sortDirection,
            sortField: sortField,
            userCanChange: userCanChange
        )
    }
}

public extension Array where Element == SavedView {

    static var previewValue: Self {
        (1 ... 5).map {
            .testValue(
                id: .init($0),
                name: "SavedView \($0)"
            )
        }
    }
}
