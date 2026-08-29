import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveFavoriteUseCase: Sendable {

    public var execute: @Sendable (_ document: Document, _ server: Server) async throws -> Void
}

extension SaveFavoriteUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in })

    public static let testValue = Self(execute: { _, _ in })
}

public extension DependencyValues {

    var saveFavorite: SaveFavoriteUseCase {
        get { self[SaveFavoriteUseCase.self] }
        set { self[SaveFavoriteUseCase.self] = newValue }
    }
}
