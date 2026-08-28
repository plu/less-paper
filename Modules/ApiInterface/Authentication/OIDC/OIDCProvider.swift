import Foundation

/// A single sign-on provider a paperless server has been configured with.
///
/// Read from the server rather than chosen by the app: which providers exist, and under what client
/// id, is the administrator's decision and can change without the app being rebuilt.
public struct OIDCProvider: Equatable, Hashable, Identifiable, Sendable {

    public let clientId: String

    public let configurationURL: URL

    public let id: String

    public let name: String

    public init(
        clientId: String,
        configurationURL: URL,
        id: String,
        name: String
    ) {
        self.clientId = clientId
        self.configurationURL = configurationURL
        self.id = id
        self.name = name
    }
}

public extension OIDCProvider {

    static func testValue(
        clientId: String = "c0ff33",
        configurationURL: URL = URL(string: "https://sso.example.com/.well-known/openid-configuration")!,
        id: String = "authentik",
        name: String = "Authentik"
    ) -> Self {
        .init(
            clientId: clientId,
            configurationURL: configurationURL,
            id: id,
            name: name
        )
    }
}
