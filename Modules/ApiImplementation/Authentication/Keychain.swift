import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSecurity

@DependencyClient
struct Keychain: Sendable {
    var getCredentials: @Sendable (
        _ server: Server
    ) async throws -> Credentials

    var getPdfPasswords: @Sendable () async throws -> [PdfPassword]

    var setPdfPasswords: @Sendable (
        _ pdfPasswords: [PdfPassword]
    ) async throws -> Void

    var storeCredentials: @Sendable (
        _ credentials: Credentials,
        _ server: Server
    ) async throws -> Void
}

extension Keychain: TestDependencyKey {
    static let testValue = Self(
        getCredentials: { _ in .testValue() },
        getPdfPasswords: { [] },
        setPdfPasswords: { _ in },
        storeCredentials: { _, _ in }
    )
}

extension DependencyValues {
    var keychain: Keychain {
        get { self[Keychain.self] }
        set { self[Keychain.self] = newValue }
    }
}

extension Keychain: DependencyKey {
    static let liveValue = Self(
        getCredentials: getCredentials(server:),
        getPdfPasswords: getPdfPasswords,
        setPdfPasswords: setPdfPasswords(pdfPasswords:),
        storeCredentials: storeCredentials(credentials:server:)
    )
}

private extension Keychain {
    static func getCredentials(
        server: Server
    ) async throws -> Credentials {
        try Credentials(
            // Optional, and not with `.get()`: a provider login stores no password, and reading one
            // that was never written must not fail the whole lookup - the token is what the app
            // actually needs.
            password: try? keychain.retrieve(
                .credential(for: "\(server.id).password")
            ).get(),
            token: keychain.retrieve(
                .credential(for: "\(server.id).token")
            ).get()
        )
    }

    static func storeCredentials(
        credentials: Credentials,
        server: Server
    ) async throws {
        for id in ["password", "token"].map({ "\(server.id).\($0)" }) {
            _ = try? keychain.remove(.credential(for: id))
        }
        if let password = credentials.password {
            try keychain.store(
                password,
                query: .credential(for: "\(server.id).password")
            )
        }
        try keychain.store(
            credentials.token,
            query: .credential(for: "\(server.id).token")
        )
    }

    // The whole list lives in one item. SwiftSecurity stores any SecDataConvertible, and Data
    // conforms, so the array is JSON-encoded rather than spread across per-password items whose
    // ordering and labels would have to ride along in keychain attributes.
    static func getPdfPasswords() async throws -> [PdfPassword] {
        guard let data: Data = try keychain.retrieve(.credential(for: pdfPasswordsKey)) else {
            return []
        }
        return try JSONDecoder.apiDecoder.decode([PdfPassword].self, from: data)
    }

    static func setPdfPasswords(pdfPasswords: [PdfPassword]) async throws {
        _ = try? keychain.remove(.credential(for: pdfPasswordsKey))
        try keychain.store(
            JSONEncoder.apiEncoder.encode(pdfPasswords),
            query: .credential(for: pdfPasswordsKey)
        )
    }

    private static let pdfPasswordsKey = "pdf-passwords"

    private static let keychain = SwiftSecurity.Keychain(
        accessGroup: .keychainGroup(
            teamID: "HZ7YVCSB89",
            nameID: "com.aptumtek.app.Paperless"
        )
    )
}
