import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ServerListReducer.self)
public struct ServerListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.servers, action: \.servers))) { store in
                ServerRowView(store: store)
            }
        }
        .overlay(emptyListView())
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.servers)
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(
                state: \.destination?.serverForm,
                action: \.destination.serverForm
            )
        ) { store in
            ServerFormView(store: store)
                .presentationDetents([.large])
        }
        .toolbar {
            Button(action: {
                send(.createServerButtonTapped)
            }) {
                Label(.createServer, systemImage: "plus")
            }
        }
    }

    public init(store: StoreOf<ServerListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<ServerListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.servers.isEmpty {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "server.rack",
                    title: .noServersFound
                ) {
                    Button {
                        send(.createServerButtonTapped)
                    } label: {
                        Label(.createServer, systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary())
                }
            }
        }
    }
}

#Preview {
    ServerListView(
        store: Store(
            initialState: ServerListReducer.State(),
            reducer: {
                ServerListReducer()
            }
        )
    )
}
