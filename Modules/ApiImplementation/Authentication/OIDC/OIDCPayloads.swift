import ApiInterface
import Foundation

// The wire shapes. Kept together and kept private to the module: these mirror what allauth and an
// OpenID provider send, not anything the app models.

struct HeadlessConfig: Decodable {

    struct DataContainer: Decodable {
        let socialaccount: SocialAccount
    }

    struct SocialAccount: Decodable {
        let providers: [ApiProvider]
    }

    struct ApiProvider: Decodable {
        let clientId: String?
        let configurationURL: String?
        let id: String
        let name: String

        enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
            case configurationURL = "openid_configuration_url"
            case id
            case name
        }

        /// A provider without a client id or a configuration URL cannot be used, so it is dropped
        /// rather than offered as a button that cannot work.
        var provider: OIDCProvider? {
            guard let clientId,
                  let configurationURL,
                  let url = URL(string: configurationURL)
            else {
                return nil
            }

            return OIDCProvider(
                clientId: clientId,
                configurationURL: url,
                id: id,
                name: name
            )
        }
    }

    let data: DataContainer
}

/// What allauth's `provider/token` expects.
///
/// The credential is nested under `token`, not sent alongside `provider` and `process`. A flat body
/// is answered with `400` and two errors that both name `token` - "This field is required" and
/// "Invalid token" - which reads like the id_token was rejected rather than never found.
struct ProviderTokenRequest: Encodable {

    struct Token: Encodable {
        let clientId: String
        let idToken: String

        enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
            case idToken = "id_token"
        }
    }

    let process: String
    let provider: String
    let token: Token
}

struct Discovery: Decodable {

    let authorizationEndpoint: URL
    let tokenEndpoint: URL

    enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
    }
}

struct ProviderToken: Decodable {

    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

struct OAuthFailure: Decodable {

    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

/// allauth says precisely what it did not like, and it is worth repeating rather than reporting a
/// status code. A flat provider/token body comes back as "This field is required" naming `token`,
/// which points straight at the mistake.
struct HeadlessFailure: Decodable {

    struct Failure: Decodable {
        let code: String?
        let message: String?
        let param: String?
    }

    let errors: [Failure]?

    var summary: String? {
        guard let errors, !errors.isEmpty else {
            return nil
        }

        return errors
            .map { failure in
                [failure.message, failure.param.map { "(\($0))" }]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }
            .joined(separator: " ")
    }
}

struct TokenResponse: Decodable {

    struct Meta: Decodable {
        let accessToken: String?
        let sessionToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case sessionToken = "session_token"
        }
    }

    let meta: Meta
}
