import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct TrashRowView: View {

    let document: Document
    let isWorking: Bool
    let deleteForever: () -> Void
    let restore: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(document.title).foregroundColor(Color.m3OnSurface)
                .clipShape(Rectangle())
            if let deletedAt = document.deletedAt {
                Text(.trashDeletedAt(deletedAt.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption)
                    .foregroundColor(.m3Outline)
            }
        }
        .accessibilityElement()
        .accessibilityValue(accessibilityValue)
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(isWorking ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    private var accessibilityValue: String {
        guard let deletedAt = document.deletedAt else {
            return document.title
        }

        return [
            document.title,
            String(localized: .trashDeletedAt(deletedAt.formatted(date: .abbreviated, time: .shortened)))
        ].joined(separator: ", ")
    }

    // Restore first, so a full swipe reaches the reversible action rather than the permanent one.
    //
    // Neither is `role: .destructive`: that makes SwiftUI remove the row the moment the button is
    // tapped, before the confirmation has been answered, so declining left the document in the
    // trash with no row to show it.
    @ViewBuilder
    private func swipeActions() -> some View {
        Button(action: restore) {
            Image(systemName: "arrow.uturn.backward")
        }
        .accessibilityLabel(.trashRestore)
        .disabled(isWorking)
        .tint(.m3Primary)

        Button(action: deleteForever) {
            Image(systemName: "trash")
        }
        .accessibilityLabel(.trashDeleteForever)
        .disabled(isWorking)
        .tint(.m3Error)
    }
}
