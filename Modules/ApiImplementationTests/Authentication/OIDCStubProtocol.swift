@testable import ApiImplementation

import Foundation

/// The canned answers the OIDC steps are tested against.
enum OIDCStub {
    case noProviders
    case notFound
    case providers
    case unusableProvider

    static let discoveryBody = #"""
    {"authorization_endpoint": "https://sso.example.com/authorize",
     "token_endpoint": "https://sso.example.com/token"}
    """#

    func statusCode(for url: URL) -> Int {
        switch self {
        case .notFound where !url.isDiscovery: 404
        default: 200
        }
    }

    /// Routed by URL, because a login makes several different requests and answering them all with
    /// the same body fails at whichever step parses first.
    func body(for url: URL) -> String {
        url.isDiscovery ? Self.discoveryBody : configBody
    }

    private var configBody: String {
        switch self {
        case .noProviders:
            #"{"data": {"socialaccount": {"providers": []}}}"#
        case .notFound:
            "not paperless"
        case .providers:
            #"""
            {"data": {"socialaccount": {"providers": [
              {"id": "authentik", "name": "Authentik", "client_id": "the-client-id",
               "openid_configuration_url": "https://sso.example.com/.well-known/openid-configuration"}
            ]}}}
            """#
        case .unusableProvider:
            // No client id: allauth lists a provider that has not been finished, and a button for
            // it could only fail.
            #"{"data": {"socialaccount": {"providers": [{"id": "half", "name": "Half"}]}}}"#
        }
    }
}

/// Answers every request from `OIDCStubProtocol.current` instead of the network.
class OIDCStubProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var current: OIDCStub?

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OIDCStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with _: URLRequest) -> Bool {
        current != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let stub = Self.current, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode(for: url),
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body(for: url).utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URL {

    var isDiscovery: Bool {
        absoluteString.contains("openid-configuration")
    }
}
