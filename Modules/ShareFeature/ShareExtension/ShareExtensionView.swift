import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ShareExtensionReducer.self)
public struct ShareExtensionView: View {

    public var body: some View {
        switch store.error {
        case let .importFailed(message):
            importFailedView(message: message)
        case .missingServer:
            missingServerView()
        case .none:
            if let store = store.scope(state: \.shareForm, action: \.shareForm) {
                ShareFormView(store: store)
            } else {
                loadingView().onAppear { send(.onAppear) }
            }
        }
    }

    public init(store: StoreOf<ShareExtensionReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<ShareExtensionReducer>

    @ViewBuilder
    private func loadingView() -> some View {
        ZStack {
            Color.m3SurfaceContainerLowest
            ProgressView()
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private func missingServerView() -> some View {
        ContentUnavailableView {
            EmptyListView(
                systemImage: "server.rack",
                title: .noServersFound
            ) {
                Text(.noServersFoundInfo)
                    .font(.body)
                    .foregroundStyle(Color.m3OnSurface)

                Button {
                    send(.dismiss)
                } label: {
                    Text(.close)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        }
        .background(Color.m3SurfaceContainerLowest)
    }

    @ViewBuilder
    private func importFailedView(message: String?) -> some View {
        ContentUnavailableView {
            EmptyListView(
                systemImage: "square.and.arrow.up.trianglebadge.exclamationmark",
                title: .importFailed
            ) {
                if let message {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Color.m3OnSurface)
                }

                Button {
                    send(.dismiss)
                } label: {
                    Text(.close)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        }
        .background(Color.m3SurfaceContainerLowest)
    }
}
