import ApiInterface
import Dependencies
import Foundation
import Get

extension APIClient {

    static func client(server: Server) -> APIClient {
        APIClient(baseURL: server.url) {
            $0.decoder = .apiDecoder
            $0.delegate = ApiClientDelegate(server: server)
            $0.sessionDelegate = Dependency(\.certificateDelegate).wrappedValue
            $0.encoder = .apiEncoder
        }
    }
}
