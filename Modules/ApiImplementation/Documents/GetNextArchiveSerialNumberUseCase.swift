import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetNextArchiveSerialNumberUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetNextArchiveSerialNumberUseCase {

    static func execute(
        server: Server
    ) async throws -> Int {
        @Dependency(\.documentsRepository)
        var documentsRepository

        return try await documentsRepository.getNextArchiveSerialNumber(
            server: server
        )
    }
}
