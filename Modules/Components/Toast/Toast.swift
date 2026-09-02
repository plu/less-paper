import DesignTokens
import SwiftUI

public enum Toast: Equatable, Hashable, Sendable {
    case error(String)
    case success(String)

    var backgroundColor: Color {
        switch self {
        case .error:
            .m3ErrorContainer
        case .success:
            .m3PrimaryContainer
        }
    }

    var foregroundColor: Color {
        switch self {
        case .error:
            .m3OnErrorContainer
        case .success:
            .m3OnPrimaryContainer
        }
    }

    var imageName: String {
        switch self {
        case .error:
            "xmark.circle"
        case .success:
            "checkmark.circle"
        }
    }

    var message: String {
        switch self {
        case let .error(message):
            message
        case let .success(message):
            message
        }
    }
}
