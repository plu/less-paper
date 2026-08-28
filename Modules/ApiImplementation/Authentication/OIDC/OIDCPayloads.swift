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
