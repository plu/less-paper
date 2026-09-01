import Components
import ComposableArchitecture
import DesignTokens
import Logging
import SwiftUI

@ViewAction(for: DiagnosticsListReducer.self)
public struct DiagnosticsListView: View {

    public var body: some View {
        Group {
            if store.entries.isEmpty, store.isLoaded {
                ContentUnavailableView {
                    EmptyListView(systemImage: "text.page", title: .diagnosticsEmpty) {
                        Text(.diagnosticsEmptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(Color.m3OnSurface)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                List {
                    ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                        DiagnosticsRowView(entry: entry)
                            .listRowSeparator(.hidden)
                            // Alternating rows: unbroken monospace is hard to scan, and this is
                            // read by someone being asked to check it before sending it on.
                            .listRowBackground(
                                index.isMultiple(of: 2)
                                    ? Color.m3SurfaceContainerLowest
                                    : Color.m3SurfaceContainerLow
                            )
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.diagnostics)
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !store.fileURLs.isEmpty {
                        // ShareLink over the files, so the user can open and read them in the share
                        // sheet before deciding. Nothing is transmitted by the app itself.
                        ShareLink(items: store.fileURLs) {
                            Label(.diagnosticsShare, systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(role: .destructive) {
                        send(.clearButtonTapped)
                    } label: {
                        Label(.diagnosticsClear, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(store.entries.isEmpty)
            }
        }
    }

    public init(store: StoreOf<DiagnosticsListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<DiagnosticsListReducer>
}
