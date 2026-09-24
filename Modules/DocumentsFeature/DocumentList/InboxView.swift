import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import FileTasksFeature
import SwiftUI

@ViewAction(for: DocumentListReducer.self)
public struct InboxView: View {
    public var body: some View {
        AdaptiveNavigationView(path: $store.scope(state: \.path, action: \.path)) {
            List {
                if store.isTipInvitationVisible {
                    // Animated on both paths: the row is answered at most once in a user's
                    // lifetime, and having it vanish between two frames reads as a glitch rather
                    // than as the app acknowledging what they just did.
                    TipInvitationBanner(
                        tapped: { send(.tipInvitationTapped, animation: .default) },
                        dismissed: { send(.tipInvitationDismissed, animation: .default) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.x3)
                }
                // Rows default to `systemBackground`, which is black in dark mode and so paints over
                // the list's `m3SurfaceContainerLowest`. Invisible in light mode, where both are white.
                ForEach(Array(store.scope(state: \.documents, action: \.documents))) { rowStore in
                    DocumentRowView(store: rowStore)
                        .documentSelectionOverlay(
                            document: rowStore.document.id,
                            store: documentSelectionStore
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .onAppear { send(.onRowAppear(rowStore.document)) }
                        .padding(.x3)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            clearInboxTagsButton(for: rowStore)
                        }
                }
                if store.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                            .id(UUID())
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.x3)
                }
                Spacer()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .background(Color.m3SurfaceContainerLowest)
            .documentListBottomToolbar(store: store, viewAction: send)
            .documentListTopLeadingToolbar(store: store, type: .inbox, viewAction: send)
            .documentListTopTrailingToolbar(store: store, viewAction: send)
            .listStyle(.plain)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(.inbox)
            .overlay(alignment: .bottom) {
                DocumentListStatusBarView(store: store)
            }
            .overlay(documentSelectionLoadingView())
            .overlay(DocumentListEmptyView(store: store))
            .refreshable { await send(.onRefresh).finish() }
            .scrollContentBackground(.hidden)
            .task { await send(.onAppear).finish() }
        } destination: { store in
            switch store.case {
            case let .documentDetail(store):
                DocumentDetailView(store: store)
            }
        } placeholder: {
            DocumentDetailPlaceholderView()
        }
        // The reducer decides whether opening a document pushes or replaces, so it has to be told
        // which layout is on screen. Read here rather than inside the container, because the
        // container is generic over features that may not care.
        .onAppear { send(.onLayoutChanged(isSplit: horizontalSizeClass == .regular)) }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            send(.onLayoutChanged(isSplit: sizeClass == .regular))
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.fileTasks,
                action: \.destination.fileTasks
            )
        ) { store in
            FileTaskListView(store: store)
                .presentationDetents([.sheet])
        }
        .badge(inboxDocumentCount)
    }

    public init(store: StoreOf<DocumentListReducer>) {
        self.store = store
        self._inboxDocumentCount = Shared(.inboxDocumentCount(store.server))
    }

    @Bindable
    public var store: StoreOf<DocumentListReducer>

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @Shared
    private var inboxDocumentCount: Int

    // Not `role: .destructive`: that removes the row the moment it is tapped, before the server has
    // agreed, which is the trap TrashRowView documents.
    //
    // Hidden while a selection is running, where the row already carries its own tap gesture and a
    // checkmark, and hidden for a document none of the filter's inbox tags actually cover - the
    // swipe would otherwise report having cleared tags it never touched.
    @ViewBuilder
    private func clearInboxTagsButton(
        for rowStore: StoreOf<DocumentRowReducer>
    ) -> some View {
        if !store.documentSelection.isActive, !rowStore.inboxTags.isEmpty {
            Button {
                rowStore.send(.view(.clearInboxTagsButtonTapped))
            } label: {
                Image(systemName: "tray.and.arrow.down")
            }
            .accessibilityLabel(.clearInboxTags)
            .disabled(rowStore.isBusy)
            .tint(.m3Primary)
        }
    }

    @ViewBuilder
    private func documentSelectionLoadingView() -> some View {
        if store.documentSelection.isLoading {
            ZStack {
                ProgressView()
                    .controlSize(.large)
                    .id(UUID())
            }
        }
    }

    @ViewBuilder
    private func statusBarView() -> some View {
        if !store.documents.isEmpty && store.totalNumberOfDocuments > 0 {
            Text(.numberOfLoadedDocuments(
                loaded: store.documents.count,
                total: store.totalNumberOfDocuments
            ))
            .capsule(
                backgroundColor: .m3Primary,
                font: .footnote,
                foregroundColor: .m3OnPrimary
            )
            .padding(.x3)
        }
    }

    private var documentSelectionStore: StoreOf<DocumentSelectionReducer> {
        store.scope(
            state: \.documentSelection,
            action: \.documentSelection
        )
    }
}

#Preview {
    InboxView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                DocumentListReducer()
            }
        )
    )
}
