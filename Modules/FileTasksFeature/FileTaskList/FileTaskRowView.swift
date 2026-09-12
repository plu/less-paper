import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct FileTaskRowView: View {

    let task: FileTask
    let canDismiss: Bool
    let isDismissing: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .x1) {
            HStack(spacing: .x2) {
                Image(systemName: task.status.systemImage)
                    .foregroundStyle(task.status.tint)
                Text(task.fileName ?? String(localized: .fileTasks))
                    .foregroundColor(Color.m3OnSurface)
                    .clipShape(Rectangle())
            }
            Text(verbatim: (task.dateDone ?? task.dateCreated)
                .formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.m3Outline)
            if let message = task.message, task.status == .failed {
                // Selectable and unclipped: a reason the user can neither read in full nor copy into
                // a bug report is no better than no reason at all.
                Text(message)
                    .font(.caption)
                    .foregroundColor(.m3Error)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement()
        .accessibilityValue(accessibilityValue)
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(isDismissing ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    private var accessibilityValue: String {
        [
            task.fileName,
            (task.dateDone ?? task.dateCreated).formatted(date: .abbreviated, time: .shortened),
            task.status == .failed ? task.message : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    // Not `role: .destructive`: that removes the row the moment it is tapped, before the server has
    // agreed, which is the trap TrashRowView documents.
    @ViewBuilder
    private func swipeActions() -> some View {
        if canDismiss {
            Button(action: dismiss) {
                Image(systemName: "checkmark.circle")
            }
            .accessibilityLabel(.fileTasksDismiss)
            .disabled(isDismissing)
            .tint(.m3Primary)
        }
    }
}

private extension FileTaskStatus {

    var systemImage: String {
        switch self {
        case .complete:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        case .queued:
            "clock"
        case .started:
            "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .complete:
            .m3Primary
        case .failed:
            .m3Error
        case .queued, .started:
            .m3Outline
        }
    }
}
