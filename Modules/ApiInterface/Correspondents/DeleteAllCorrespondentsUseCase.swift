import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteAllCorrespondentsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension DeleteAllCorrespondentsUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteAllCorrespondents: DeleteAllCorrespondentsUseCase {
        get { self[DeleteAllCorrespondentsUseCase.self] }
        set { self[DeleteAllCorrespondentsUseCase.self] = newValue }
    }
}
