import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteShareLinkUseCase: Sendable {

    public var execute: @Sendable (
        _ id: ShareLink.Id,
        _ server: Server
    ) async throws -> Void
}

extension DeleteShareLinkUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {

    var deleteShareLink: DeleteShareLinkUseCase {
        get { self[DeleteShareLinkUseCase.self] }
        set { self[DeleteShareLinkUseCase.self] = newValue }
    }
}
