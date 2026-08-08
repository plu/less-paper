import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveCorrespondentUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Correspondent.Id?,
        _ input: SaveCorrespondentInput,
        _ server: Server
    ) async throws -> SaveCorrespondentOutput
}

extension SaveCorrespondentUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var saveCorrespondent: SaveCorrespondentUseCase {
        get { self[SaveCorrespondentUseCase.self] }
        set { self[SaveCorrespondentUseCase.self] = newValue }
    }
}
