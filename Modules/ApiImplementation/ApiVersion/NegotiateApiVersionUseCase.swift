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
        var apiVersion: Int

        let negotiated = try ApiVersion.negotiated(
            from: try await repository.getAdvertisedApiVersion(server: server)
        )

        $apiVersion.withLock { $0 = negotiated }

        return negotiated
    }
}
