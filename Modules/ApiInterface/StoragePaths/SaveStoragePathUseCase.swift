import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveStoragePathUseCase: Sendable {

    public var execute: @Sendable (
        _ id: StoragePath.Id?,
        _ input: SaveStoragePathInput,
        _ server: Server
    ) async throws -> SaveStoragePathOutput
}

extension SaveStoragePathUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var saveStoragePath: SaveStoragePathUseCase {
        get { self[SaveStoragePathUseCase.self] }
        set { self[SaveStoragePathUseCase.self] = newValue }
    }
}
