import DesignTokens
import SwiftUI

@MainActor
public enum ButtonType: Int, CaseIterable {
    case primary
    case secondary
    case ghost
    case critical
}

extension ButtonType {

    var backgroundColor: Color {
        switch self {
        case .primary:
            .m3Primary
        case .secondary:
            .clear
        case .ghost:
            .clear
        case .critical:
            .clear
        }
    }

    var borderColor: Color {
        switch self {
        case .primary:
            .clear
        case .secondary:
            .m3Primary
        case .ghost:
            .clear
        case .critical:
            .m3Error
        }
    }

    var titleColor: Color {
        switch self {
        case .primary:
            .m3OnPrimary
        case .secondary:
            .m3Primary
        case .ghost:
            .m3Primary
        case .critical:
            .m3Error
        }
    }

    var backgroundColorDisabled: Color {
        switch self {
        case .primary:
            backgroundColor.opacity(0.6)
        case .secondary,
             .ghost,
             .critical:
            backgroundColor.opacity(0.4)
        }
    }

    var borderColorDisabled: Color {
        switch self {
        case .primary:
            borderColor.opacity(0.6)
        case .secondary,
             .ghost,
             .critical:
            borderColor.opacity(0.4)
        }
    }

    var titleColorDisabled: Color {
        switch self {
        case .primary:
            titleColor.opacity(0.6)
        case .secondary,
             .ghost,
             .critical:
            titleColor.opacity(0.4)
        }
    }

    var backgroundColorPressed: Color {
        switch self {
        case .primary:
            .m3PrimaryContainer
        case .secondary:
            .m3PrimaryContainer
        case .ghost:
            .m3PrimaryContainer
        case .critical:
            .m3ErrorContainer
        }
    }

    var borderColorPressed: Color {
        switch self {
        case .primary:
            .m3PrimaryContainer
        case .secondary:
            .m3Primary
        case .ghost:
            .clear
        case .critical:
            .m3Error
        }
    }

    var titleColorPressed: Color {
        switch self {
        case .primary:
            .m3OnPrimaryContainer
        case .secondary:
            .m3OnPrimaryContainer
        case .ghost:
            .m3OnPrimaryContainer
        case .critical:
            .m3OnErrorContainer
        }
    }
}
