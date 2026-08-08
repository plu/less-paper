import ApiInterface
import Dependencies
import DependenciesMacros
import SwiftSecurity

@DependencyClient
struct Keychain: Sendable {
    var getCredentials: @Sendable (
        _ server: Server
    ) async throws -> Credentials

    var storeCredentials: @Sendable (
        _ credentials: Credentials,
        _ server: Server
    ) async throws -> Void
}

extension Keychain: TestDependencyKey {
    static let testValue = Self(
        getCredentials: { _ in .testValue() },
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
        storeCredentials: storeCredentials(credentials:server:)
    )
}

private extension Keychain {
    static func getCredentials(
        server: Server
    ) async throws -> Credentials {
        try Credentials(
            password: keychain.retrieve(
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
        try keychain.store(
            credentials.password,
            query: .credential(for: "\(server.id).password")
        )
        try keychain.store(
            credentials.token,
            query: .credential(for: "\(server.id).token")
        )
    }

    private static let keychain = SwiftSecurity.Keychain(
        accessGroup: .keychainGroup(
            teamID: "HZ7YVCSB89",
            nameID: "com.aptumtek.app.Paperless"
        )
    )
}
