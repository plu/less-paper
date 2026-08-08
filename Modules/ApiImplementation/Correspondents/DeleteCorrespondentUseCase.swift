import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteCorrespondentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DeleteCorrespondentUseCase {

    static func execute(
        id: Correspondent.Id,
        server: Server
    ) async throws {
        @Shared(.correspondents(server))
        var cache: IdentifiedArrayOf<Correspondent> = []

        @Dependency(\.correspondentsRepository)
        var correspondentsRepository

        try await correspondentsRepository.deleteCorrespondent(
            id: id,
            server: server
        )

        _ = $cache.withLock { $0.remove(id: id) }
    }
}
