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

    public let settings: Settings

    public let user: User

    // Optional, and the optionality is load-bearing: nil means the server did not send the key - an
    // older paperless - while [] means it sent an empty list. contains() answers false for every
    // permission on an empty array, so collapsing the two would hide every control in the app for
    // anyone on an older server.
    public let permissions: [Permission]?

    public init(
        settings: Settings,
        user: User,
        permissions: [Permission]? = nil
    ) {
        self.settings = settings
        self.user = user
        self.permissions = permissions
    }
}

public extension UISettings {

    private enum CodingKeys: String, CodingKey {
        case permissions, settings, user
    }

    // @SkipUnknownValues wraps [T], not [T]?, so it cannot carry the nil/empty distinction above.
    // Decoding by hand here, with the same MaybeDecodable the wrapper uses, keeps that distinction
    // while still skipping permission codenames this enum does not know.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(Settings.self, forKey: .settings)
        user = try container.decode(User.self, forKey: .user)
        permissions = try container
            .decodeIfPresent([MaybeDecodable<Permission>].self, forKey: .permissions)?
            .compactMap(\.wrapped)
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
        user: ApiInterface.User = .testValue(),
        permissions: [Permission]? = nil
    ) -> Self {
        .init(
            settings: settings,
            user: user,
            permissions: permissions
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
