import Foundation

enum DeepLinkError: Error, Equatable {
    case serverNotFound(host: String)
}

extension DeepLinkError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case let .serverNotFound(host):
            String(localized: .deepLinkServerNotFound(host))
        }
    }
}
