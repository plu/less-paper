import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import SwiftUI

@ViewAction(for: DocumentViewerReducer.self)
struct DocumentViewerView: View {
    var body: some View {
        // Inverted from DocumentFormView on both counts: content here is a plain Text that needs
        // the sheet to scroll it, and the notes list spans the sheet edge to edge and insets its
        // own rows instead.
        Sheet(
            isScrollingEnabled: store.isContentScrollable,
            padding: store.section == .customFields || store.section == .notes ? 0 : .x4
        ) {
            SheetHeader(
                title: store.section.localized,
                left: {
                    SheetCloseButton {
                        send(.closeButtonTapped)
                    }
                },
                right: {
                    sectionMenu()
                }
            )
        } content: {
            switch store.section {
            case .content:
                contentSection()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .customFields:
                DocumentCustomFieldsView(store: customFieldsStore)
            case .metadata:
                DocumentMetadataView(store: metadataStore)
            case .notes:
                DocumentNotesView(store: notesStore, isReadOnly: true)
            }
        }
        .onAppear { send(.onAppear) }
        .sheet(
            item: $store.scope(
                state: \.destination?.documentDetail,
                action: \.destination.documentDetail
            )
        ) { store in
            // DocumentDetailView puts its title and its whole toolbar on a navigation bar, which
            // exists only inside a NavigationStack. Pushed from the document list it inherits one;
            // presented as a sheet it has none, and SwiftUI drops both without complaint.
            NavigationStack {
                DocumentDetailView(store: store)
                    // Inline, unlike the pushed detail: a document title is long enough that a large
                    // one takes a third of the sheet and still truncates.
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            // A pushed detail is left by its back button. A presented one has none,
                            // so it needs somewhere to go besides a swipe.
                            DocumentDetailSheetCloseButton()
                        }
                    }
            }
            .presentationDetents([.large])
        }
    }

    @Bindable
    var store: StoreOf<DocumentViewerReducer>

    private var customFieldsStore: StoreOf<DocumentCustomFieldsReducer> {
        store.scope(state: \.customFields, action: \.customFields)
    }

    private var metadataStore: StoreOf<DocumentMetadataReducer> {
        store.scope(state: \.metadata, action: \.metadata)
    }

    private var notesStore: StoreOf<DocumentNotesReducer> {
        store.scope(state: \.notes, action: \.notes)
    }

    @ViewBuilder
    private func sectionMenu() -> some View {
        Menu {
            Picker("", selection: $store.section) {
                ForEach(DocumentViewerSection.allCases, id: \.self) {
                    Text($0.localized).tag($0)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .sheetHeaderTapTarget()
                .accessibilityLabel(.moreOptions)
        }
    }

    @ViewBuilder
    private func contentSection() -> some View {
        if let loadError = store.loadError {
            EmptyListView(
                systemImage: "text.page.badge.magnifyingglass",
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
        } else if !store.hasLoadedContent {
            ProgressView()
                .controlSize(.large)
        } else if let content = store.document.content, !content.isEmpty {
            // Selectable: reading a scan and copying a reference number out of it is the same trip.
            Text(content)
                .font(.body)
                .foregroundStyle(Color.m3OnSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        } else {
            EmptyListView(
                systemImage: "text.page.badge.magnifyingglass",
                title: .noContentFound
            )
        }
    }
}

#Preview {
    DocumentViewerView(
        store: Store(
            initialState: DocumentViewerReducer.State.testValue(hasLoadedContent: true),
            reducer: {
                DocumentViewerReducer()
            }
        )
    )
}

// Dismisses through the environment rather than by sending an action: the sheet is bound to the
// destination, so SwiftUI clearing it is what tells the reducer.
private struct DocumentDetailSheetCloseButton: View {

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .accessibilityLabel(.close)
        }
    }

    @Environment(\.dismiss)
    private var dismiss
}
