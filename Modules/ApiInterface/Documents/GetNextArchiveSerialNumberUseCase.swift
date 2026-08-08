import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetNextArchiveSerialNumberUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Int
}

extension GetNextArchiveSerialNumberUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in 1 }
    )

    public static let testValue = Self(
        execute: { _ in 1 }
    )
}

public extension DependencyValues {
    var getNextArchiveSerialNumber: GetNextArchiveSerialNumberUseCase {
        get { self[GetNextArchiveSerialNumberUseCase.self] }
        set { self[GetNextArchiveSerialNumberUseCase.self] = newValue }
    }
}
