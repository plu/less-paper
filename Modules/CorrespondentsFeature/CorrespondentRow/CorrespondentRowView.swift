import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import DesignTokens
import SwiftUI

@ViewAction(for: CorrespondentRowReducer.self)
struct CorrespondentRowView: View {

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.correspondent.name).foregroundColor(Color.m3OnSurface)
                .clipShape(Rectangle())
            Text(.numberOfDocuments(store.correspondent.documentCount))
                .font(.caption)
                .foregroundColor(.m3Outline)
        }
        .accessibilityElement()
        .accessibilityValue([
            store.correspondent.name,
            String(localized: .numberOfDocuments(store.correspondent.documentCount))
        ].joined(separator: ", "))
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(store.isUpdating ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    var store: StoreOf<CorrespondentRowReducer>

    @ViewBuilder
    private func swipeActions() -> some View {
        if store.canEdit {
            Button {
                send(.editButtonTapped)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel(.editCorrespondent)
            .tint(.m3Primary)
        }

        if store.canDelete {
            Button {
                send(.deleteButtonTapped)
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel(.deleteCorrespondent)
            .tint(.m3Error)
        }
    }
}

#Preview {
    List {
        CorrespondentRowView(
            store: Store(
                initialState: CorrespondentRowReducer.State(
                    server: .testValue(),
                    correspondent: .testValue()
                ),
                reducer: {
                    CorrespondentRowReducer()
                }
            )
        )
    }
}
