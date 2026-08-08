import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension GetSelectionDataUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension GetSelectionDataUseCase {

    static func execute(
        input: GetSelectionDataInput,
        server: Server
    ) async throws -> GetSelectionDataOutput {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getSelectionData(
            input: input,
            server: server
        )
    }
}
