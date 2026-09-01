import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct DocumentNoteRowView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: .x3) {
            Text(note.note)
                .foregroundStyle(Color.m3OnSurface)
            Text([
                note.user.description,
                DateFormatter.noteCreated.string(from: note.created),
            ].joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Color.m3Outline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.x4)
        .background(Color.m3SurfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .accessibilityElement()
        .accessibilityValue([
            note.note,
            note.user.description,
            DateFormatter.noteCreated.string(from: note.created),
        ].joined(separator: ", "))
        .listRowBackground(Color.clear)
        // The list is edge to edge, so the row carries the sheet's horizontal inset itself.
        .listRowInsets(EdgeInsets(top: .x3, leading: .x4, bottom: .x3, trailing: .x4))
        .listRowSeparator(.hidden)
        .opacity(isDeleting ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    let isDeleting: Bool

    let note: Note

    // nil in the read-only viewer, where a swipe must not reveal a delete the sheet does not offer.
    let deleteButtonTapped: (() -> Void)?

    @ViewBuilder
    private func swipeActions() -> some View {
        if let deleteButtonTapped {
            Button(action: deleteButtonTapped) {
                Image(systemName: "trash")
            }
            .accessibilityLabel(.deleteNote)
            .tint(.m3Error)
        }
    }
}

#Preview {
    List {
        DocumentNoteRowView(
            isDeleting: false,
            note: .testValue(),
            deleteButtonTapped: {}
        )
    }
    .listStyle(.plain)
}
