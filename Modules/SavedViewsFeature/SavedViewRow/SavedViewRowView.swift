import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import SwiftUI

@ViewAction(for: SavedViewRowReducer.self)
struct SavedViewRowView: View {

    var body: some View {
        HStack(spacing: .x3) {
            Text(store.savedView.name).foregroundColor(Color.m3OnSurface)
                .clipShape(Rectangle())
            Spacer()
            HStack(spacing: .x2) {
                if store.savedView.showInSidebar {
                    Image(systemName: "sidebar.left").accessibilityLabel(.showInSidebar)
                }
                if store.savedView.showOnDashboard {
                    Image(systemName: "house").accessibilityLabel(.showOnDashboard)
                }
            }
            .font(.caption)
            .foregroundColor(.m3Outline)
        }
        .accessibilityElement()
        .accessibilityValue([
            store.savedView.name,
            store.savedView.showInSidebar ? String(localized: .showInSidebar) : nil,
            store.savedView.showOnDashboard ? String(localized: .showOnDashboard) : nil
        ].compactMap { $0 }.joined(separator: ", "))
        .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(store.isUpdating ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    @Bindable
    var store: StoreOf<SavedViewRowReducer>

    @ViewBuilder
    private func swipeActions() -> some View {
        Button {
            send(.editButtonTapped)
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel(.editSavedView)
        .tint(.m3Primary)

        Button {
            send(.deleteButtonTapped)
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel(.deleteSavedView)
        .tint(.m3Error)
    }
}

#Preview {
    List {
        SavedViewRowView(
            store: Store(
                initialState: SavedViewRowReducer.State(
                    savedView: .testValue(),
                    server: .testValue()
                ),
                reducer: {
                    SavedViewRowReducer()
                }
            )
        )
    }
}
