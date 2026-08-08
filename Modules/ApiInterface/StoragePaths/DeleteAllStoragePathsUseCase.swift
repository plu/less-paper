import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteAllStoragePathsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension DeleteAllStoragePathsUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteAllStoragePaths: DeleteAllStoragePathsUseCase {
        get { self[DeleteAllStoragePathsUseCase.self] }
        set { self[DeleteAllStoragePathsUseCase.self] = newValue }
    }
}
