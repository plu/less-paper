import ApiInterface
import Components
import DesignTokens
import SwiftUI
import TagsFeature

struct DocumentSearchRowView: View {

    var body: some View {
        HStack(spacing: .x3) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.m3Primary)
                .frame(width: .x4)
            switch title {
            // Carried as a tag rather than as its name so it keeps the colour it has everywhere
            // else in the app; `.tag(tag:font:)` is TagsFeature's own capsule.
            case let .tag(tag):
                Text(tag.name).tag(tag: tag, font: .body)
            case let .text(text):
                Text(text)
                    .foregroundStyle(Color.m3OnSurface)
                    .lineLimit(1)
            }
            Spacer()
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Color.m3Outline)
            }
        }
        .contentShape(.rect)
    }

    init(
        caption: String? = nil,
        systemImage: String,
        title: String
    ) {
        self.caption = caption
        self.systemImage = systemImage
        self.title = .text(title)
    }

    init(
        systemImage: String,
        tag: Tag
    ) {
        caption = nil
        self.systemImage = systemImage
        title = .tag(tag)
    }

    // A tag renders as a capsule and a name renders as text, and the two carry different payloads.
    // Splitting them here is what stops a caller handing over both and having one silently ignored.
    private enum Title {
        case tag(Tag)
        case text(String)
    }

    private let caption: String?
    private let systemImage: String
    private let title: Title
}
