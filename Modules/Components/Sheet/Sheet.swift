import DesignTokens
import SwiftUI

public struct Sheet<Top: View, Content: View, ContentOverlay: View, Bottom: View>: View {
    public var body: some View {
        VStack(spacing: 0) {
            if !(top is EmptyView) && verticalSizeClass != .compact {
                top
                    .font(.body)
                    .fontWeight(.semibold)
                    .padding(.x4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.m3Primary)
                    .foregroundStyle(Color.m3OnPrimary)
                    .dynamicTypeSize(.xSmall ... .xxLarge)
            }

            if isScrollingEnabled {
                ScrollView {
                    content.padding(padding)
                }
                .overlay(contentOverlay)
            } else {
                content
                    .overlay(contentOverlay)
                    .padding(padding)
            }

            if !(bottom is EmptyView) {
                VStack(spacing: 0) {
                    Divider()
                    bottom.padding()
                }
            }
        }
        .background(Color.m3Surface)
    }

    public init(
        isScrollingEnabled: Bool = true,
        padding: CGFloat = .x4,
        @ViewBuilder top: () -> Top,
        @ViewBuilder content: () -> Content,
        @ViewBuilder contentOverlay: () -> ContentOverlay,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.bottom = bottom()
        self.content = content()
        self.contentOverlay = contentOverlay()
        self.isScrollingEnabled = isScrollingEnabled
        self.padding = padding
        self.top = top()
    }

    private let bottom: Bottom
    private let content: Content
    private let contentOverlay: ContentOverlay
    private let isScrollingEnabled: Bool
    private let padding: CGFloat
    private let top: Top

    @Environment(\.verticalSizeClass)
    private var verticalSizeClass
}

public extension Sheet where Top == EmptyView, ContentOverlay == EmptyView, Bottom == EmptyView {

    init(
        isScrollingEnabled: Bool = true,
        padding: CGFloat = .x4,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            isScrollingEnabled: isScrollingEnabled,
            padding: padding,
            top: EmptyView.init,
            content: content,
            contentOverlay: EmptyView.init,
            bottom: EmptyView.init
        )
    }
}

public extension Sheet where Top == EmptyView, ContentOverlay == EmptyView {

    init(
        isScrollingEnabled: Bool = true,
        padding: CGFloat = .x4,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.init(
            isScrollingEnabled: isScrollingEnabled,
            padding: padding,
            top: EmptyView.init,
            content: content,
            contentOverlay: EmptyView.init,
            bottom: bottom
        )
    }
}

public extension Sheet where Bottom == EmptyView, ContentOverlay == EmptyView {

    init(
        isScrollingEnabled: Bool = true,
        padding: CGFloat = .x4,
        @ViewBuilder top: () -> Top,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            isScrollingEnabled: isScrollingEnabled,
            padding: padding,
            top: top,
            content: content,
            contentOverlay: EmptyView.init,
            bottom: EmptyView.init
        )
    }
}

public extension Sheet where ContentOverlay == EmptyView {

    init(
        isScrollingEnabled: Bool = true,
        padding: CGFloat = .x4,
        @ViewBuilder top: () -> Top,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.init(
            isScrollingEnabled: isScrollingEnabled,
            padding: padding,
            top: top,
            content: content,
            contentOverlay: EmptyView.init,
            bottom: bottom
        )
    }
}
