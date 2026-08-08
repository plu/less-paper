import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import SwiftUI

@ViewAction(for: DocumentTypeRowReducer.self)
struct DocumentTypeRowView: View {

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.documentType.name).foregroundColor(Color.m3OnSurface)
                .clipShape(Rectangle())
            Text(.numberOfDocuments(store.documentType.documentCount))
                .font(.caption)
                .foregroundColor(.m3Outline)
        }
        .accessibilityElement()
        .accessibilityValue([
            store.documentType.name,
            String(localized: .numberOfDocuments(store.documentType.documentCount))
        ].joined(separator: ", "))
        .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(store.isUpdating ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    @Bindable
    var store: StoreOf<DocumentTypeRowReducer>

    @ViewBuilder
    private func swipeActions() -> some View {
        Button {
            send(.editButtonTapped)
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel(.editDocumentType)
        .tint(.m3Primary)

        Button {
            send(.deleteButtonTapped)
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel(.deleteDocumentType)
        .tint(.m3Error)
    }
}

#Preview {
    List {
        DocumentTypeRowView(
            store: Store(
                initialState: DocumentTypeRowReducer.State.testValue(),
                reducer: {
                    DocumentTypeRowReducer()
                }
            )
        )
    }
}
