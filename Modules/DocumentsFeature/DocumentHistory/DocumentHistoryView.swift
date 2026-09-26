import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import SwiftUI

@ViewAction(for: DocumentHistoryReducer.self)
struct DocumentHistoryView: View {

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentHistoryReducer>

    @Dependency(\.date.now)
    private var now

    @ViewBuilder
    private func content() -> some View {
        if let loadError = store.loadError {
            EmptyListView(
                systemImage: "clock.arrow.circlepath",
                title: .init(stringLiteral: loadError)
            ) {
                Button {
                    send(.retryLoadButtonTapped)
                } label: {
                    Text(.retry)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        } else if let entries = store.entries {
            if entries.isEmpty {
                EmptyListView(
                    systemImage: "clock.arrow.circlepath",
                    title: .noHistoryFound
                )
            } else {
                List(entries) { entry in
                    DocumentHistoryEntryView(entry: entry, now: now, server: store.server)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}

#Preview {
    DocumentHistoryView(
        store: Store(
            initialState: DocumentHistoryReducer.State.testValue(entries: [.testValue()]),
            reducer: {
                DocumentHistoryReducer()
            }
        )
    )
}
