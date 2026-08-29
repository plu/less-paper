import Foundation

enum TipJarError: Error, Equatable {
    case productUnavailable
}

extension TipJarError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            String(localized: .tipProductUnavailable)
        }
    }
}
