import Dependencies
import DependenciesMacros
import Foundation

public struct FavoriteRefreshResult: Equatable, Sendable {

    public let failed: Int

    public let unavailable: Int

    public let updated: Int

    public init(failed: Int = 0, unavailable: Int = 0, updated: Int = 0) {
        self.failed = failed
        self.unavailable = unavailable
        self.updated = updated
    }
}

@DependencyClient
public struct RefreshFavoritesUseCase: Sendable {

    // `force` is what separates pull-to-refresh from Settings' "Redownload all": the same walk,
    // with phase two run for every favorite instead of only the changed ones.
    public var execute: @Sendable (
        _ force: Bool,
        _ server: Server
    ) async throws -> FavoriteRefreshResult
}

extension RefreshFavoritesUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in .init() })

    public static let testValue = Self(execute: { _, _ in .init() })
}

public extension DependencyValues {

    var refreshFavorites: RefreshFavoritesUseCase {
        get { self[RefreshFavoritesUseCase.self] }
        set { self[RefreshFavoritesUseCase.self] = newValue }
    }
}
