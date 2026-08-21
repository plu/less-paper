import Foundation

public struct SetSavedViewVisibilityInput: Codable, Equatable, Sendable {

    public var showInSidebar: Bool

    public var showOnDashboard: Bool

    public init(
        showInSidebar: Bool,
        showOnDashboard: Bool
    ) {
        self.showInSidebar = showInSidebar
        self.showOnDashboard = showOnDashboard
    }
}

public extension SetSavedViewVisibilityInput {

    static func testValue(
        showInSidebar: Bool = true,
        showOnDashboard: Bool = false
    ) -> Self {
        .init(
            showInSidebar: showInSidebar,
            showOnDashboard: showOnDashboard
        )
    }
}
