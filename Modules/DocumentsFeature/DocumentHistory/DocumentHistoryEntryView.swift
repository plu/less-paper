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
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.m3OnSurface)
                Spacer(minLength: .x2)
                actionBadge()
            }
            .font(.caption)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line: line)
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

    // The same capsule a tag gets, so the badge reads as a label rather than a button.
    @ViewBuilder
    private func actionBadge() -> some View {
        let isCreate = entry.action == .create
        Text(actionTitle)
            .capsule(
                backgroundColor: isCreate ? .m3PrimaryContainer : .m3SurfaceContainerHighest,
                font: .caption,
                foregroundColor: isCreate ? .m3OnPrimaryContainer : .m3OnSurfaceVariant
            )
    }

    // The read-only Field the metadata section uses, so a change reads like the value it set.
    @ViewBuilder
    private func lineView(line: DocumentHistoryChangeLine) -> some View {
        Field(LocalizedStringResource(stringLiteral: line.label)) {
            Text(line.value)
                .font(.body)
                .foregroundStyle(Color.m3OnSurface)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .readOnly()
        .accessibilityElement()
        .accessibilityLabel(Text(line.label))
        .accessibilityValue(line.value)
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
