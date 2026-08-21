import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension SavePdfPasswordUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(filename:password:)
    )
}

private extension SavePdfPasswordUseCase {

    static func execute(
        filename: String,
        password: String
    ) async throws {
        @Dependency(\.keychain)
        var keychain

        @Dependency(\.uuid)
        var uuid

        let stored = try await keychain.getPdfPasswords()

        guard !stored.contains(where: { $0.password == password }) else {
            return
        }

        try await keychain.setPdfPasswords(
            stored + [PdfPassword(filename: filename, id: uuid().uuidString, password: password)]
        )
    }
}
