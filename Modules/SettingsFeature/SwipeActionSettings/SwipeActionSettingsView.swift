import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: SwipeActionSettingsReducer.self)
public struct SwipeActionSettingsView: View {

    public var body: some View {
        Form {
            section(.swipeActionsInboxLeading, screen: .inbox, edge: .leading)
            section(.swipeActionsInboxTrailing, screen: .inbox, edge: .trailing)
            section(.swipeActionsDocumentsLeading, screen: .documents, edge: .leading)
            section(.swipeActionsDocumentsTrailing, screen: .documents, edge: .trailing)
            Section {
                Button(role: .destructive) {
                    send(.resetButtonTapped)
                } label: {
                    Text(.swipeActionsReset)
                }
            }
        }
        .navigationTitle(.swipeActions)
        .navigationBarTitleDisplayMode(.inline)
    }

    public init(store: StoreOf<SwipeActionSettingsReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<SwipeActionSettingsReducer>

    @ViewBuilder
    private func section(
        _ title: LocalizedStringResource,
        screen: SwipeActionSettingsReducer.Screen,
        edge: SwipeActionSettingsReducer.Edge
    ) -> some View {
        let selected = store.settings[screen, edge]
        Section {
            ForEach(DocumentSwipeAction.allCases, id: \.self) { action in
                Button {
                    send(.actionTapped(screen: screen, edge: edge, action: action))
                } label: {
                    HStack {
                        Label {
                            Text(action.localized)
                        } icon: {
                            Image(systemName: action.systemImage)
                        }
                        Spacer()
                        // The position rather than a tick: with two slots, which one a full swipe
                        // runs is the thing the user needs to see.
                        if let index = selected.firstIndex(of: action) {
                            Text("\(index + 1)")
                                .fontWeight(.bold)
                                .foregroundStyle(Color.m3Primary)
                        }
                    }
                }
                .foregroundStyle(Color.m3OnSurface)
            }
        } header: {
            Text(title)
        } footer: {
            Text(.swipeActionsFooter)
        }
    }
}

#Preview {
    NavigationStack {
        SwipeActionSettingsView(
            store: Store(initialState: SwipeActionSettingsReducer.State()) {
                SwipeActionSettingsReducer()
            }
        )
    }
}
