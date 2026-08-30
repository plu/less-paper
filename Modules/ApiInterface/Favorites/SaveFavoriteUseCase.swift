import Dependencies
import DependenciesMacros
import Foundation

// Refresh and favoriting share this use case, and they want opposite things from a document that
// was unfavorited while the fetch was in flight: the add path must write it, a refresh must not
// resurrect it.
public enum SaveFavoriteMode: Equatable, Sendable {
    case add
    case refreshExisting
}

@DependencyClient
public struct SaveFavoriteUseCase: Sendable {

    public var execute: @Sendable (
        _ document: Document,
        _ server: Server,
        _ mode: SaveFavoriteMode
    ) async throws -> Void
}

extension SaveFavoriteUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _, _ in })

    public static let testValue = Self(execute: { _, _, _ in })
}

public extension DependencyValues {

    var saveFavorite: SaveFavoriteUseCase {
        get { self[SaveFavoriteUseCase.self] }
        set { self[SaveFavoriteUseCase.self] = newValue }
    }
}
