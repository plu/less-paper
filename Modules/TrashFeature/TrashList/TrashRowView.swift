import ApiInterface
import Components
import SwiftUI

struct TrashRowView: View {

    let document: Document
    let isWorking: Bool
    let deleteForever: () -> Void
    let restore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .x1) {
            Text(document.title)
                .font(.body)
                .foregroundStyle(Color.m3OnSurface)

            if let deletedAt = document.deletedAt {
                Text(.trashDeletedAt(deletedAt.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption)
                    .foregroundStyle(Color.m3OnSurface.opacity(0.6))
            }
        }
        .padding(.vertical, .x1)
        .opacity(isWorking ? 0.4 : 1)
        // Swipe actions rather than buttons in the row: the destructive one should take a
        // deliberate gesture, and this is how deleting works everywhere else here.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: deleteForever) {
                Label(.trashDeleteForever, systemImage: "trash")
            }
            .disabled(isWorking)

            Button(action: restore) {
                Label(.trashRestore, systemImage: "arrow.uturn.backward")
            }
            .tint(.m3Primary)
            .disabled(isWorking)
        }
    }
}
