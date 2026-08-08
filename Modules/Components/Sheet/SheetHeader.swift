import SwiftUI

public struct SheetHeader<Left: View, Title: View, Right: View>: View {

    public var body: some View {
        HStack(spacing: .x0) {
            if let left, !(left is EmptyView) {
                left.frame(size: SheetHeaderConstants.size)
            } else {
                Spacer().frame(size: SheetHeaderConstants.size)
            }
            Spacer()
            title
                .accessibilityAddTraits(.isHeader)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let right, !(right is EmptyView) {
                right.frame(size: SheetHeaderConstants.size)
            } else {
                Spacer().frame(size: SheetHeaderConstants.size)
            }
        }
    }

    public init(
        @ViewBuilder title: () -> Title,
        @ViewBuilder left: () -> Left? = { EmptyView?.none },
        @ViewBuilder right: () -> Right? = { EmptyView?.none }
    ) {
        self.left = left()
        self.right = right()
        self.title = title()
    }

    private let left: Left?

    private let right: Right?

    private let title: Title
}

public extension SheetHeader where Title == Text {

    init(
        title: LocalizedStringResource,
        @ViewBuilder left: () -> Left? = { EmptyView?.none },
        @ViewBuilder right: () -> Right? = { EmptyView?.none }
    ) {
        self.init(
            title: { Text(title) },
            left: left,
            right: right
        )
    }
}

public enum SheetHeaderConstants {

    public static let size = CGSize(width: 60, height: 60)
}
