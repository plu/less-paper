import Foundation

public struct GetUISettingsInput: Codable, Equatable, Sendable {

    public init() {}
}

public extension GetUISettingsInput {

    static func testValue(
    ) -> Self {
        .init(
        )
    }
}
