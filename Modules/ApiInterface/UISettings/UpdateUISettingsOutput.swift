import Foundation

public struct UpdateUISettingsOutput: Codable, Equatable, Sendable {

    public let success: Bool

    public init(
        success: Bool
    ) {
        self.success = success
    }
}

public extension UpdateUISettingsOutput {

    static func testValue(
        success: Bool = true
    ) -> Self {
        .init(
            success: success
        )
    }
}
