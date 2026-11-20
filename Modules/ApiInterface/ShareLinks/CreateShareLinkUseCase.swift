import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct CreateShareLinkUseCase: Sendable {

    public var execute: @Sendable (
        _ input: CreateShareLinkInput,
        _ server: Server
    ) async throws -> ShareLink
}

extension CreateShareLinkUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var createShareLink: CreateShareLinkUseCase {
        get { self[CreateShareLinkUseCase.self] }
        set { self[CreateShareLinkUseCase.self] = newValue }
    }
}
