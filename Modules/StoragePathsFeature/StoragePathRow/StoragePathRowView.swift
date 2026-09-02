import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import DesignTokens
import SwiftUI

@ViewAction(for: StoragePathRowReducer.self)
struct StoragePathRowView: View {

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.storagePath.name).foregroundColor(Color.m3OnSurface)
                .clipShape(Rectangle())
            Text(.numberOfDocuments(store.storagePath.documentCount))
                .font(.caption)
                .foregroundColor(.m3Outline)
        }
        .accessibilityElement()
        .accessibilityValue([
            store.storagePath.name,
            String(localized: .numberOfDocuments(store.storagePath.documentCount))
        ].joined(separator: ", "))
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(store.isUpdating ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    var store: StoreOf<StoragePathRowReducer>

    @ViewBuilder
    private func swipeActions() -> some View {
        Button {
            send(.editButtonTapped)
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel(.editStoragePath)
        .tint(.m3Primary)

        Button {
            send(.deleteButtonTapped)
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel(.deleteStoragePath)
        .tint(.m3Error)
    }
}

#Preview {
    List {
        StoragePathRowView(
            store: Store(
                initialState: StoragePathRowReducer.State(
                    storagePath: .testValue(),
                    server: .testValue()
                ),
                reducer: {
                    StoragePathRowReducer()
                }
            )
        )
    }
}
