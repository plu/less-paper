import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteAllTagsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension DeleteAllTagsUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteAllTags: DeleteAllTagsUseCase {
        get { self[DeleteAllTagsUseCase.self] }
        set { self[DeleteAllTagsUseCase.self] = newValue }
    }
}
