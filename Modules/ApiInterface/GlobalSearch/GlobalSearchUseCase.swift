import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GlobalSearchUseCase: Sendable {

    public var execute: @Sendable (
        _ query: String,
        _ server: Server
    ) async throws -> GlobalSearchOutput
}

extension GlobalSearchUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var globalSearch: GlobalSearchUseCase {
        get { self[GlobalSearchUseCase.self] }
        set { self[GlobalSearchUseCase.self] = newValue }
    }
}
