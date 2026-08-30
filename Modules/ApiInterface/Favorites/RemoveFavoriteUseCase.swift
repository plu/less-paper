import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct RemoveFavoriteUseCase: Sendable {

    public var execute: @Sendable (_ id: Document.Id, _ server: Server) async throws -> Void
}

extension RemoveFavoriteUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in })

    public static let testValue = Self(execute: { _, _ in })
}

public extension DependencyValues {

    var removeFavorite: RemoveFavoriteUseCase {
        get { self[RemoveFavoriteUseCase.self] }
        set { self[RemoveFavoriteUseCase.self] = newValue }
    }
}
