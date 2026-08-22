import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import SwiftSharing
import SwiftUI

@ViewAction(for: ServerRowReducer.self)
struct ServerRowView: View {

    var body: some View {
        Button {
            send(.serverTapped)
        } label: {
            HStack(spacing: .x3) {
                VStack(alignment: .leading) {
                    Text(store.server.alias)
                        .foregroundColor(Color.m3OnSurface)
                    Text([store.server.username, store.server.url.absoluteString].joined(separator: " @ "))
                        .font(.caption)
                        .foregroundColor(.m3Outline)
                }
                if store.isSelecting {
                    Spacer()
                    ProgressView()
                } else if selectedServer == store.server {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundStyle(Color.m3Outline)
                }
            }
            .accessibilityElement()
            .accessibilityValue([
                store.server.username,
                store.server.alias,
                store.server.url.absoluteString
            ].joined(separator: ", "))
        }
        .listRowBackground(Color.m3SurfaceContainer)
        .swipeActions(content: swipeActions)
    }

    var store: StoreOf<ServerRowReducer>

    @ViewBuilder
    private func swipeActions() -> some View {
        Button {
            send(.editButtonTapped)
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel(.editServer)
        .tint(.m3Primary)

        Button {
            send(.deleteButtonTapped)
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel(.deleteServer)
        .tint(.m3Error)
    }

    @Shared(.selectedServer)
    private var selectedServer: Server?
}

#Preview {
    List {
        ServerRowView(
            store: Store(
                initialState: ServerRowReducer.State(
                    server: .testValue()
                ),
                reducer: {
                    ServerRowReducer()
                }
            )
        )
    }
}
