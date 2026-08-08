import Foundation

public enum ButtonSize: Int, CaseIterable {
    case regular
    case small
}

extension ButtonSize {

    var cornerRadius: CGFloat {
        Constants.cornerRadius
    }

    var height: CGFloat {
        switch self {
        case .regular:
            44
        case .small:
            32
        }
    }

    var horizontalPadding: CGFloat {
        16
    }
}
