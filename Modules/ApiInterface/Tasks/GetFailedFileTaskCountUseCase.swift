import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetFailedFileTaskCountUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Int
}

extension GetFailedFileTaskCountUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in 0 }
    )

    public static let testValue = Self(
        execute: { _ in 0 }
    )
}

public extension DependencyValues {

    var getFailedFileTaskCount: GetFailedFileTaskCountUseCase {
        get { self[GetFailedFileTaskCountUseCase.self] }
        set { self[GetFailedFileTaskCountUseCase.self] = newValue }
    }
}
