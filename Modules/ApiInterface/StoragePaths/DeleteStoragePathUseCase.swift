import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteStoragePathUseCase: Sendable {

    public var execute: @Sendable (
        _ id: StoragePath.Id,
        _ server: Server
    ) async throws -> Void
}

extension DeleteStoragePathUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteStoragePath: DeleteStoragePathUseCase {
        get { self[DeleteStoragePathUseCase.self] }
        set { self[DeleteStoragePathUseCase.self] = newValue }
    }
}
