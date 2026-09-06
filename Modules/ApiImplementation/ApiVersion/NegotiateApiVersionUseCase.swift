import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension NegotiateApiVersionUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension NegotiateApiVersionUseCase {

    static func execute(
        server: Server
    ) async throws -> Int {
        @Dependency(\.apiVersionRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        @Shared(.paperlessVersion(server))
        var paperlessVersion: String?

        let versions = try await repository.getServerVersions(server: server)
        let negotiated = try ApiVersion.negotiated(from: versions.apiVersion)

        $apiVersion.withLock { $0 = negotiated }
        // Written even when nil: a server that stops sending the header should stop reporting a
        // version rather than keep showing the last one it sent.
        $paperlessVersion.withLock { $0 = versions.paperlessVersion }

        return negotiated
    }
}
