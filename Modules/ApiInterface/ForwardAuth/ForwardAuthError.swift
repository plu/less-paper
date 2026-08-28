import Foundation

public enum ForwardAuthError: Equatable, Error, LocalizedError, Sendable {
    case required(URL)
}

public extension ForwardAuthError {

    var errorDescription: String? {
        switch self {
        case let .required(url):
            guard let host = url.host() else {
                return String(localized: .forwardAuthRequired)
            }
            return String(localized: .forwardAuthRequiredWithHost(host))
        }
    }
}
