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
        .contentShape(Rectangle())
        .onTapGesture {
            send(.revealButtonTapped, animation: .default)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                send(.deleteButtonTapped)
            } label: {
                Label(.delete, systemImage: "trash")
            }
        }
    }
}
