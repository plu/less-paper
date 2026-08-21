import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetPdfPasswordsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute
    )
}

private extension GetPdfPasswordsUseCase {

    static func execute() async throws -> [PdfPassword] {
        @Dependency(\.keychain)
        var keychain

        return try await keychain.getPdfPasswords()
    }
}
