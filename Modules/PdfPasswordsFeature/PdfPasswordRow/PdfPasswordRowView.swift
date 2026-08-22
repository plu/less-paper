import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PdfPasswordRowReducer.self)
struct PdfPasswordRowView: View {

    @Bindable var store: StoreOf<PdfPasswordRowReducer>

    var body: some View {
        VStack(alignment: .leading, spacing: .x1) {
            Text(store.pdfPassword.filename)
                .font(.body)
                .foregroundStyle(Color.m3OnSurface)

            Text(store.isRevealed ? store.pdfPassword.password : "••••••••")
                .font(.footnote.monospaced())
                .foregroundStyle(Color.m3OnSurface.opacity(0.7))
        }
        // The VStack sizes to its text, so contentShape alone would leave the rest of the row dead
        // to taps.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            send(.revealButtonTapped, animation: .default)
        }
        .swipeActions(edge: .trailing) {
            // Not `role: .destructive`: that makes the List animate the row away the moment the
            // button is tapped, leaving the row gone even when the confirmation is cancelled.
            Button {
                send(.deleteButtonTapped)
            } label: {
                Label(.delete, systemImage: "trash")
            }
            .accessibilityLabel(.deletePdfPassword)
            .tint(.m3Error)
        }
    }
}
