import SwiftUI

public struct EmptyListView<Content: View>: View {

    public var body: some View {
        VStack(spacing: .x4) {
            Image(systemName: systemImage)
                .aspectRatio(contentMode: .fit)
                .font(.system(size: 128))
                .fontWeight(.medium)
                .foregroundStyle(Color.m3OutlineVariant)

            if let title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.m3OnSurface)
            }

            if !(content is EmptyView) {
                content
                    .padding(.top, .x5)
            }
        }
        .containerRelativeFrame(.horizontal, count: 10, span: 6, spacing: 0)
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .foregroundStyle(Color.m3SurfaceContainerLow)
                .padding(-.x5)
        )
    }

    public init(
        systemImage: String,
        title: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Content = EmptyView.init
    ) {
        self.content = content()
        self.systemImage = systemImage
        self.title = title
    }

    private let content: Content

    private let systemImage: String

    private let title: LocalizedStringResource?
}

#Preview {
    List {}
        .background(Color.m3Surface)
        .overlay(
            EmptyListView(
                systemImage: "tag.circle",
                title: "No tags found"
            ) {
                Button {} label: {
                    Label("Add tag", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        )
        .refreshable {}
}
