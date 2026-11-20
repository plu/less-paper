import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetShareLinksUseCase: Sendable {

    public var execute: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [ShareLink]
}

extension GetShareLinksUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _, _ in [.testValue()] }
    )
}

public extension DependencyValues {

    var getShareLinks: GetShareLinksUseCase {
        get { self[GetShareLinksUseCase.self] }
        set { self[GetShareLinksUseCase.self] = newValue }
    }
}
