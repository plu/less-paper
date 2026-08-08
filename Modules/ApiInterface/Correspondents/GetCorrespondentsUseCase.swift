import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetCorrespondentsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [Correspondent]
}

extension GetCorrespondentsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {
    var getCorrespondents: GetCorrespondentsUseCase {
        get { self[GetCorrespondentsUseCase.self] }
        set { self[GetCorrespondentsUseCase.self] = newValue }
    }
}
