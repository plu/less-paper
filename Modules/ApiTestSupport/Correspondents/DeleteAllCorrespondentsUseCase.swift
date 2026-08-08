import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections

extension DeleteAllCorrespondentsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension DeleteAllCorrespondentsUseCase {

    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.getCorrespondents.execute)
        var getCorrespondents

        @Dependency(\.deleteCorrespondent.execute)
        var deleteCorrespondent

        let correspondents = try await getCorrespondents(server)

        for correspondent in correspondents {
            try await deleteCorrespondent(correspondent.id, server)
        }
    }
}
