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
            padding: store.section == .notes ? 0 : .x4
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
            case .notes:
                DocumentNotesView(store: notesStore, isReadOnly: true)
            }
        }
        .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentViewerReducer>

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
