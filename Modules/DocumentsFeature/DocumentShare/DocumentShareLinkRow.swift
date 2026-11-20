import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct DocumentShareLinkRow: View {

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: .x1) {
                Text(displayURL)
                    .foregroundStyle(Color.m3OnSurface)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(expiry)
                    .font(.caption)
                    .foregroundStyle(Color.m3OnSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .accessibilityHint(.copyLinkHint)
        .listRowBackground(Color.m3SurfaceContainer)
        .swipeActions(content: swipeActions)
    }

    let link: ApiInterface.ShareLink

    let now: Date

    let onDelete: (() -> Void)?

    let onShare: () -> Void

    let onTap: () -> Void

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

    @ViewBuilder
    private func swipeActions() -> some View {
        Button(action: onShare) {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel(.shareLinkNamed(link.slug))
        .tint(.m3Primary)

        if let onDelete {
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityLabel(.deleteLinkNamed(link.slug))
            .tint(.m3Error)
        }
    }
}
