import Foundation

public enum ApiVersionError: Error, Equatable {
    case unsupportedServer(Int?)
}

extension ApiVersionError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .unsupportedServer(advertised?):
            String(localized: .unsupportedServerApiVersion(advertised, ApiVersion.minimumSupported))
        case .unsupportedServer:
            String(localized: .unsupportedServerApiVersionUnknown)
        }
    }
}
