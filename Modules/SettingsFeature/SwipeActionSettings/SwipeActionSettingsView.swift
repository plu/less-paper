import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: SwipeActionSettingsReducer.self)
public struct SwipeActionSettingsView: View {

    public var body: some View {
        List {
            section(
                .swipeActionsLeading,
                footer: .swipeActionsLeadingFooter,
                edge: .leading
            )
            section(
                .swipeActionsTrailing,
                footer: .swipeActionsTrailingFooter,
                edge: .trailing
            )
            Section {
                Button(role: .destructive) {
                    send(.resetButtonTapped)
                } label: {
                    Text(.swipeActionsReset)
                }
                .listRowBackground(Color.m3SurfaceContainer)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.swipeActions)
        .scrollContentBackground(.hidden)
    }

    public init(store: StoreOf<SwipeActionSettingsReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<SwipeActionSettingsReducer>

    @ViewBuilder
    private func section(
        _ title: LocalizedStringResource,
        footer: LocalizedStringResource,
        edge: SwipeActionSettingsReducer.Edge
    ) -> some View {
        let selected = store.settings[edge]
        Section {
            ForEach(DocumentSwipeAction.configurable, id: \.self) { action in
                Button {
                    send(.actionTapped(edge: edge, action: action))
                } label: {
                    HStack {
                        Label {
                            Text(action.localized)
                                .foregroundStyle(Color.m3OnSurface)
                        } icon: {
                            // Tinted per element rather than on the Button: a foregroundStyle on the
                            // label paints the glyph too, and every other row in Settings keeps its
                            // icon in the accent with the text in the body colour.
                            Image(systemName: action.systemImage)
                                .foregroundStyle(Color.m3Primary)
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
                .listRowBackground(Color.m3SurfaceContainer)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
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
