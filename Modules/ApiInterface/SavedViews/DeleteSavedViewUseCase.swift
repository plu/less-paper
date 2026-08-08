import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteSavedViewUseCase: Sendable {

    public var execute: @Sendable (
        _ id: SavedView.Id,
        _ server: Server
    ) async throws -> Void
}

extension DeleteSavedViewUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteSavedView: DeleteSavedViewUseCase {
        get { self[DeleteSavedViewUseCase.self] }
        set { self[DeleteSavedViewUseCase.self] = newValue }
    }
}
