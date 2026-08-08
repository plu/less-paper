import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct UpdateCacheUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension UpdateCacheUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {

    var updateCache: UpdateCacheUseCase {
        get { self[UpdateCacheUseCase.self] }
        set { self[UpdateCacheUseCase.self] = newValue }
    }
}
