import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteTagUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Tag.Id,
        _ server: Server
    ) async throws -> Void
}

extension DeleteTagUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteTag: DeleteTagUseCase {
        get { self[DeleteTagUseCase.self] }
        set { self[DeleteTagUseCase.self] = newValue }
    }
}
