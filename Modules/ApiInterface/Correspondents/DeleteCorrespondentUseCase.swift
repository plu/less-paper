import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteCorrespondentUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Correspondent.Id,
        _ server: Server
    ) async throws -> Void
}

extension DeleteCorrespondentUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteCorrespondent: DeleteCorrespondentUseCase {
        get { self[DeleteCorrespondentUseCase.self] }
        set { self[DeleteCorrespondentUseCase.self] = newValue }
    }
}
