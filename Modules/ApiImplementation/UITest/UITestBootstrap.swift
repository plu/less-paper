import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

// Called from the app's initialiser. prepareDependencies is an app-launch API, so the two halves
// below stay separate: tests exercise them through withDependencies instead.
public func prepareUITestDependencies(
    _ configuration: UITestConfiguration
) {
    prepareDependencies {
        $0.applyUITestConfiguration(configuration)
    }
    seedUITestSharedState(configuration)
}

public extension DependencyValues {

    mutating func applyUITestConfiguration(
        _ configuration: UITestConfiguration
    ) {
        defaultAppStorage = .inMemory
        defaultFileStorage = .inMemory
        keychain = .uiTest(seed: configuration.seed)
    }
}

// Writing the selected server is what drives AppReducer.bootstrap's observer into
// selectedServerChanged, which builds MainReducer.State — the same path a real launch takes.
// Storage must already be in memory or these writes land in the real app group container.
public func seedUITestSharedState(
    _ configuration: UITestConfiguration
) {
    guard let seed = configuration.seed else {
        return
    }

    @Shared(.servers)
    var servers

    @Shared(.selectedServer)
    var selectedServer

    $servers.withLock { $0 = [seed.server] }
    $selectedServer.withLock { $0 = seed.server }
}

private extension Keychain {

    struct MissingCredentials: Error {}

    // A real store rather than a fixed answer: the add-server journey writes credentials through
    // StoreTokenUseCase and reads them back through GetCredentialsUseCase, and a stub that ignored
    // the write would report success without exercising either.
    static func uiTest(
        seed: UITestConfiguration.Seed?
    ) -> Self {
        let credentials = LockIsolated([String: Credentials]())
        let pdfPasswords = LockIsolated([PdfPassword]())

        if let seed {
            credentials.withValue {
                $0[seed.server.id] = Credentials(
                    password: seed.password,
                    token: seed.token
                )
            }
        }

        return Self(
            getCredentials: { server in
                guard let stored = credentials.value[server.id] else {
                    throw MissingCredentials()
                }
                return stored
            },
            getPdfPasswords: { pdfPasswords.value },
            setPdfPasswords: { pdfPasswords.setValue($0) },
            storeCredentials: { newCredentials, server in
                credentials.withValue { $0[server.id] = newCredentials }
            }
        )
    }
}
