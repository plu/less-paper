import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct NegotiateApiVersionUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Int
}

extension NegotiateApiVersionUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in ApiVersion.clientMaximum }
    )

    public static let testValue = Self(
        execute: { _ in ApiVersion.clientMaximum }
    )
}

public extension DependencyValues {
    var negotiateApiVersion: NegotiateApiVersionUseCase {
        get { self[NegotiateApiVersionUseCase.self] }
        set { self[NegotiateApiVersionUseCase.self] = newValue }
    }
}
