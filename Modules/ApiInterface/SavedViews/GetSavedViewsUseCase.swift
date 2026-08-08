import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetSavedViewsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [SavedView]
}

extension GetSavedViewsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {
    var getSavedViews: GetSavedViewsUseCase {
        get { self[GetSavedViewsUseCase.self] }
        set { self[GetSavedViewsUseCase.self] = newValue }
    }
}
