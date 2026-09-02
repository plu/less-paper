import Components
import ComposableArchitecture
import DesignTokens
import DiagnosticsFeature
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
        .navigationDestination(
            item: $store.scope(
                state: \.destination?.diagnosticsList,
                action: \.destination.diagnosticsList
            )
        ) { store in
            DiagnosticsListView(store: store)
        }
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
                    // One stack rather than two siblings of the outer one: EmptyListView spaces
                    // its children apart and pads the content, and a TupleView passes that padding
                    // to each button, which left the two of them further apart than they read as a
                    // pair.
                    VStack(spacing: .x3) {
                        Button {
                            send(.createServerButtonTapped)
                        } label: {
                            Label(.createServer, systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary())

                        // The only route to the log for someone with no server: Diagnostics
                        // otherwise lives in Settings, which is inside the tabs a selected server
                        // builds. Adding the first server is also where the log is most likely to
                        // be worth reading.
                        Button {
                            send(.diagnosticsButtonTapped)
                        } label: {
                            Label(.diagnostics, systemImage: "stethoscope")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ghost())
                    }
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
