import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetStoragePathsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [StoragePath]
}

extension GetStoragePathsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {
    var getStoragePaths: GetStoragePathsUseCase {
        get { self[GetStoragePathsUseCase.self] }
        set { self[GetStoragePathsUseCase.self] = newValue }
    }
}
