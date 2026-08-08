import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SetSavedViewVisibilityUseCase: Sendable {

    public var execute: @Sendable (
        _ savedViewId: SavedView.Id,
        _ showInSidebar: Bool,
        _ showOnDashboard: Bool,
        _ server: Server
    ) async throws -> Void
}

extension SetSavedViewVisibilityUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var setSavedViewVisibility: SetSavedViewVisibilityUseCase {
        get { self[SetSavedViewVisibilityUseCase.self] }
        set { self[SetSavedViewVisibilityUseCase.self] = newValue }
    }
}
