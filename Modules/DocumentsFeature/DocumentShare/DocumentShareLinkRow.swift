import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct DocumentShareLinkRow: View {

    var body: some View {
        AdaptiveStack {
            HStack(spacing: .x3) {
                Image(systemName: "link")
                    .foregroundStyle(Color.m3OnSurfaceVariant)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: .x1) {
                    Text(displayURL)
                        .font(.body)
                        .foregroundStyle(Color.m3OnSurface)
                        .lineLimit(3)
                        .truncationMode(.middle)
                    Text(expiry)
                        .font(.caption)
                        .foregroundStyle(Color.m3OnSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: .x3) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .accessibilityLabel(.copyLink)
                }
                .buttonStyle(.borderless)

                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .accessibilityLabel(.delete)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, .x2)
    }

    let link: ApiInterface.ShareLink

    let now: Date

    let onCopy: () -> Void

    let onDelete: (() -> Void)?

    let server: Server

    private var displayURL: String {
        link.url(server: server)?.absoluteString ?? link.slug
    }

    private var expiry: LocalizedStringResource {
        guard let expiration = link.expiration else {
            return .shareLinkNeverExpires
        }
        return .shareLinkExpiresAt(
            RelativeDateTimeFormatter().localizedString(for: expiration, relativeTo: now)
        )
    }
}
