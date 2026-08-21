import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension DeletePdfPasswordUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:)
    )
}

private extension DeletePdfPasswordUseCase {

    static func execute(
        id: String
    ) async throws {
        @Dependency(\.keychain)
        var keychain

        let stored = try await keychain.getPdfPasswords()

        try await keychain.setPdfPasswords(stored.filter { $0.id != id })
    }
}
