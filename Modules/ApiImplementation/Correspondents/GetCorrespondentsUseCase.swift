import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetCorrespondentsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetCorrespondentsUseCase {

    static func execute(
        server: Server
    ) async throws -> [Correspondent] {
        @Shared(.correspondents(server))
        var cache: IdentifiedArrayOf<Correspondent> = []

        @Dependency(\.correspondentsRepository)
        var repository

        var output = try await repository.getCorrespondents(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getCorrespondents(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
