import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: OfflineSettingsReducer.self)
public struct OfflineSettingsView: View {

    public var body: some View {
        List {
            Section {
                HStack {
                    Text(.storageUsed)
                        .foregroundStyle(Color.m3OnSurface)
                    Spacer()
                    Text(formattedByteCount)
                        .foregroundStyle(Color.m3OnSurfaceVariant)
                }
            }
            .listRowBackground(Color.m3SurfaceContainer)

            Section {
                Button {
                    send(.redownloadAllButtonTapped)
                } label: {
                    HStack {
                        Label {
                            Text(.redownloadAll)
                                .foregroundStyle(Color.m3OnSurface)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                        Spacer()
                        if store.isWorking {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isWorking)
                .listRowBackground(Color.m3SurfaceContainer)

                Button(role: .destructive) {
                    send(.removeAllButtonTapped)
                } label: {
                    Label(.removeAllOfflineDocuments, systemImage: "trash")
                }
                .disabled(store.isWorking)
                .listRowBackground(Color.m3SurfaceContainer)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.offline)
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
    }

    public init(store: StoreOf<OfflineSettingsReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<OfflineSettingsReducer>

    private var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(store.totalByteCount), countStyle: .file)
    }
}
