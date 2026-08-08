import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentListReducer.self)
struct DocumentListEmptyView: View {
    var body: some View {
        if store.documents.isEmpty && store.isLoaded {
            ContentUnavailableView {
                if let error = store.error {
                    EmptyListView(
                        systemImage: "exclamationmark.triangle",
                        title: LocalizedStringResource(stringLiteral: error),
                        content: reloadButton
                    )
                } else {
                    EmptyListView(
                        systemImage: "tray",
                        title: .noDocumentsFound,
                        content: reloadButton
                    )
                }
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentListReducer>

    @ViewBuilder
    private func reloadButton() -> some View {
        Button {
            send(.reloadButtonTapped)
        } label: {
            Label(.reload, systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
    }
}
