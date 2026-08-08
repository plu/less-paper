import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteTagUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DeleteTagUseCase {

    static func execute(
        id: Tag.Id,
        server: Server
    ) async throws {
        @Shared(.tags(server))
        var cache: IdentifiedArrayOf<Tag> = []

        @Dependency(\.tagsRepository)
        var tagsRepository

        try await tagsRepository.deleteTag(
            id: id,
            server: server
        )

        _ = $cache.withLock { $0.remove(id: id) }
    }
}
