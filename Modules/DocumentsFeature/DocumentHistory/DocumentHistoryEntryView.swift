import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct DocumentHistoryEntryView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: .x3) {
            HStack(spacing: .x2) {
                Text(relativeTimestamp)
                    .foregroundStyle(Color.m3OnSurfaceVariant)
                Text(entry.actor?.username ?? String(localized: .system))
                    .italic()
                    .foregroundStyle(Color.m3OnSurface)
                Spacer(minLength: .x2)
                actionBadge()
            }
            .font(.caption)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                (Text(line.label + ": ").foregroundStyle(Color.m3OnSurface)
                    + Text(line.value).font(.body.monospaced()).foregroundStyle(Color.m3Primary))
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.x4)
        .background(Color.m3SurfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .accessibilityElement(children: .combine)
        .listRowBackground(Color.clear)
        // The list is edge to edge, so the row carries the sheet's horizontal inset itself.
        .listRowInsets(EdgeInsets(top: .x3, leading: .x4, bottom: .x3, trailing: .x4))
        .listRowSeparator(.hidden)
    }

    let entry: AuditLogEntry

    let now: Date

    let server: Server

    private var lines: [DocumentHistoryChangeLine] {
        entry.changes.map { DocumentHistoryChangeLine(change: $0, server: server) }
    }

    private var relativeTimestamp: String {
        RelativeDateTimeFormatter().localizedString(for: entry.timestamp, relativeTo: now)
    }

    @ViewBuilder
    private func actionBadge() -> some View {
        let isCreate = entry.action == .create
        Text(actionTitle)
            .padding(.horizontal, .x2)
            .padding(.vertical, 2)
            .background(isCreate ? Color.m3PrimaryContainer : Color.m3SecondaryContainer)
            .foregroundStyle(isCreate ? Color.m3OnPrimaryContainer : Color.m3OnSecondaryContainer)
            .clipShape(Capsule())
    }

    private var actionTitle: String {
        switch entry.action {
        case .create:
            String(localized: .auditLogActionCreate)
        case .delete:
            String(localized: .auditLogActionDelete)
        case let .other(value):
            value.prefix(1).uppercased() + value.dropFirst()
        case .update:
            String(localized: .auditLogActionUpdate)
        }
    }
}
