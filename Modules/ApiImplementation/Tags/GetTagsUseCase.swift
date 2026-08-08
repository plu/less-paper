import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetTagsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetTagsUseCase {

    static func execute(
        server: Server
    ) async throws -> [Tag] {
        @Shared(.tags(server))
        var cache: IdentifiedArrayOf<Tag> = []

        @Dependency(\.tagsRepository)
        var repository

        var output = try await repository.getTags(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getTags(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
