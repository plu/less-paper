import SwiftUI

public struct AdaptiveStack<Content: View>: View {

    public var body: some View {
        if sizeCategory >= breakpoint {
            VStack(alignment: horizontalAlignment, spacing: verticalSpacing) {
                content
            }
        } else {
            HStack(alignment: verticalAlignment, spacing: horizontalSpacing) {
                content
            }
        }
    }

    public init(
        breakpoint: ContentSizeCategory = .accessibilityMedium,
        horizontalAlignment: HorizontalAlignment = .leading,
        horizontalSpacing: CGFloat = .x3,
        verticalAlignment: VerticalAlignment = .center,
        verticalSpacing: CGFloat = .x3,
        @ViewBuilder content: () -> Content
    ) {
        self.breakpoint = breakpoint
        self.content = content()
        self.horizontalAlignment = horizontalAlignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalAlignment = verticalAlignment
        self.verticalSpacing = verticalSpacing
    }

    private let content: Content

    private let breakpoint: ContentSizeCategory

    private let horizontalAlignment: HorizontalAlignment

    private let horizontalSpacing: CGFloat

    private let verticalAlignment: VerticalAlignment

    private let verticalSpacing: CGFloat

    @Environment(\.sizeCategory)
    private var sizeCategory
}
