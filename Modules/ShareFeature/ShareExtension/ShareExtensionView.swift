import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: ShareExtensionReducer.self)
public struct ShareExtensionView: View {

    public var body: some View {
        switch store.error {
        case let .importFailed(message):
            importFailedView(message: message)
        case let .importNotPermitted(serverAlias):
            importNotPermittedView(serverAlias: serverAlias)
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

    // The server is named because a multi-server user needs to know which account to fix, and the
    // share sheet is the one screen that cannot show them which server it is about any other way.
    @ViewBuilder
    private func importNotPermittedView(serverAlias: String) -> some View {
        ContentUnavailableView {
            EmptyListView(
                systemImage: "lock.document",
                title: .importNotPermitted
            ) {
                Text(.importNotPermittedInfo(serverAlias: serverAlias))
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
