import ApiInterface
import Dependencies
import Foundation
import Get

extension APIClient {

    static func client(server: Server, sendsApiVersion: Bool = true) -> APIClient {
        APIClient(baseURL: server.url) {
            $0.decoder = .apiDecoder
            $0.delegate = ApiClientDelegate(server: server, sendsApiVersion: sendsApiVersion)
            $0.encoder = .apiEncoder
            $0.sessionConfiguration = .apiClient
            $0.sessionDelegate = Dependency(\.apiSessionDelegate).wrappedValue
        }
    }
}

private extension URLSessionConfiguration {

    // Shared with the share extension through the app group. A live session in the app
    // authenticates a share without a second login through the proxy.
    static let apiClient: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = AppGroup.cookieStorage
        return configuration
    }()
}
