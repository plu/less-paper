import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DownloadDocumentUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Document.Id,
        _ server: Server
    ) async throws -> Data
}

extension DownloadDocumentUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in try .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in try .testValue() }
    )
}

public extension DependencyValues {
    var downloadDocument: DownloadDocumentUseCase {
        get { self[DownloadDocumentUseCase.self] }
        set { self[DownloadDocumentUseCase.self] = newValue }
    }
}
