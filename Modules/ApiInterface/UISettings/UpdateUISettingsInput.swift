import Foundation

public struct UpdateUISettingsInput: Codable, Equatable, Sendable {

    public var settings: [String: JSONValue]

    public init(
        settings: [String: JSONValue]
    ) {
        self.settings = settings
    }
}

public extension UpdateUISettingsInput {

    static func testValue(
        settings: [String: JSONValue] = [:]
    ) -> Self {
        .init(
            settings: settings
        )
    }
}
