import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections

extension DeleteAllTagsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension DeleteAllTagsUseCase {

    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.getTags.execute)
        var getTags

        @Dependency(\.deleteTag.execute)
        var deleteTag

        let tags = try await getTags(server)

        for tag in tags {
            try await deleteTag(tag.id, server)
        }
    }
}
