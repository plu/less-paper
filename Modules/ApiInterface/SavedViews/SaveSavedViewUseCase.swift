import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveSavedViewUseCase: Sendable {

    public var execute: @Sendable (
        _ id: SavedView.Id?,
        _ input: SaveSavedViewInput,
        _ server: Server
    ) async throws -> SaveSavedViewOutput
}

extension SaveSavedViewUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var saveSavedView: SaveSavedViewUseCase {
        get { self[SaveSavedViewUseCase.self] }
        set { self[SaveSavedViewUseCase.self] = newValue }
    }
}
