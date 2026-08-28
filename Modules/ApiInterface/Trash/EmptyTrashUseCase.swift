import Dependencies
import DependenciesMacros
import Foundation

/// Deletes documents for good.
///
/// Named for what the API calls it. An empty `ids` means everything in the trash, which is what the
/// server does with an omitted document list.
@DependencyClient
public struct EmptyTrashUseCase: Sendable {

    public var execute: @Sendable (
        _ ids: [Document.Id],
        _ server: Server
    ) async throws -> Void
}

extension EmptyTrashUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in })

    public static let testValue = Self(execute: { _, _ in })
}

public extension DependencyValues {

    var emptyTrash: EmptyTrashUseCase {
        get { self[EmptyTrashUseCase.self] }
        set { self[EmptyTrashUseCase.self] = newValue }
    }
}
