import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension DownloadDocumentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DownloadDocumentUseCase {

    static func execute(
        id: Document.Id,
        server: Server
    ) async throws -> Data {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.downloadDocument(
            id: id,
            server: server
        )
    }
}
