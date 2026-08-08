import Foundation
import Tagged

public struct UISettings: Codable, Equatable, Sendable {

    public struct Settings: Codable, Equatable, Sendable {

        public struct SavedViews: Equatable, Sendable {

            public let dashboardViewsVisibleIds: [ApiInterface.SavedView.Id]

            public let sidebarViewsVisibleIds: [ApiInterface.SavedView.Id]

            public init(
                dashboardViewsVisibleIds: [ApiInterface.SavedView.Id] = [],
                sidebarViewsVisibleIds: [ApiInterface.SavedView.Id] = []
            ) {
                self.dashboardViewsVisibleIds = dashboardViewsVisibleIds
                self.sidebarViewsVisibleIds = sidebarViewsVisibleIds
            }
        }

        public var raw: [String: JSONValue]

        public init(raw: [String: JSONValue] = [:]) {
            self.raw = raw
        }
    }

    public struct User: Codable, Equatable, Sendable {

        public let id: ApiInterface.User.Id

        public init(
            id: ApiInterface.User.Id
        ) {
            self.id = id
        }
    }

    public let settings: Settings

    public let user: User

    public init(
        settings: Settings,
        user: User
    ) {
        self.settings = settings
        self.user = user
    }
}

public extension UISettings.Settings {

    var savedViews: SavedViews? {
        get {
            guard let object = raw["saved_views"]?.objectValue else {
                return nil
            }

            let dashboardIds: [Int] = (object["dashboard_views_visible_ids"]?.arrayValue ?? []).compactMap(\.intValue)
            let sidebarIds: [Int] = (object["sidebar_views_visible_ids"]?.arrayValue ?? []).compactMap(\.intValue)

            return SavedViews(
                dashboardViewsVisibleIds: dashboardIds.map { ApiInterface.SavedView.Id($0) },
                sidebarViewsVisibleIds: sidebarIds.map { ApiInterface.SavedView.Id($0) }
            )
        }
        set {
            guard let newValue else {
                raw["saved_views"] = nil
                return
            }
            var object = raw["saved_views"]?.objectValue ?? [:]
            object["dashboard_views_visible_ids"] = .array(newValue.dashboardViewsVisibleIds.map { .number(Double($0.rawValue)) })
            object["sidebar_views_visible_ids"] = .array(newValue.sidebarViewsVisibleIds.map { .number(Double($0.rawValue)) })
            raw["saved_views"] = .object(object)
        }
    }

    var version: String {
        raw["version"]?.stringValue ?? ""
    }
}

public extension UISettings.Settings {

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        raw = try container.decode([String: JSONValue].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

public extension UISettings {

    static func testValue(
        settings: UISettings.Settings = .testValue(),
        user: UISettings.User = .testValue()
    ) -> Self {
        .init(
            settings: settings,
            user: user
        )
    }
}

public extension UISettings.Settings {

    static func testValue(
        savedViews: UISettings.Settings.SavedViews? = nil,
        version: String = "2.18.4"
    ) -> Self {
        var settings = Self(raw: ["version": .string(version)])

        settings.savedViews = savedViews
        return settings
    }
}

public extension UISettings.Settings.SavedViews {

    static func testValue(
        dashboardViewsVisibleIds: [ApiInterface.SavedView.Id] = [],
        sidebarViewsVisibleIds: [ApiInterface.SavedView.Id] = []
    ) -> Self {
        .init(
            dashboardViewsVisibleIds: dashboardViewsVisibleIds,
            sidebarViewsVisibleIds: sidebarViewsVisibleIds
        )
    }
}

public extension UISettings.User {

    static func testValue(
        id: ApiInterface.User.Id = 1
    ) -> Self {
        .init(
            id: id
        )
    }
}
