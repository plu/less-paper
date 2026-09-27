import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import Dependencies
import DesignTokens
import DocumentTypesFeature
import StoragePathsFeature
import SwiftUI
import TagsFeature

@ViewAction(for: DocumentSheetReducer.self)
struct DocumentSheetView: View {
    var body: some View {
        // Two initialisers rather than one with an empty bottom: Sheet draws its bottom bar, divider
        // and all, unless the slot's type is EmptyView, and a branch that renders nothing is not.
        Group {
            if hasBottom {
                Sheet(isScrollingEnabled: store.isSheetScrollable, padding: padding) {
                    header()
                } content: {
                    content()
                } bottom: {
                    bottom()
                }
            } else {
                Sheet(isScrollingEnabled: store.isSheetScrollable, padding: padding) {
                    header()
                } content: {
                    content()
                }
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
    var store: StoreOf<DocumentSheetReducer>

    // Reset and Save act on everything staged, whichever of the three sections it was staged in, so
    // they show on all three rather than only where the edit happened. The notes composer takes
    // their slot: nothing in the notes section is staged, so neither button would act on anything.
    private var hasBottom: Bool {
        switch store.section {
        case .content, .customFields, .details:
            store.isEditable
        case .history, .metadata:
            false
        case .notes:
            // Existence, not enablement: canAddNote is the add_note permission, while the composer's
            // own canCreate (draft non-empty, not saving) still governs whether the button inside
            // it is enabled.
            store.notes.canAddNote && !store.isOfflineSnapshot
        }
    }

    // These span the sheet edge to edge and inset their own rows instead, so a scroll indicator
    // sits at the sheet's edge and rows clip there rather than 16pt short.
    private var padding: CGFloat {
        switch store.section {
        case .customFields:
            store.isCustomFieldsEditable ? .x4 : 0
        case .history, .notes:
            0
        case .content, .details, .metadata:
            .x4
        }
    }

    private var historyStore: StoreOf<DocumentHistoryReducer> {
        store.scope(state: \.history, action: \.history)
    }

    private var metadataStore: StoreOf<DocumentMetadataReducer> {
        store.scope(state: \.metadata, action: \.metadata)
    }

    private var notesStore: StoreOf<DocumentNotesReducer> {
        store.scope(state: \.notes, action: \.notes)
    }

    private var readOnlyCustomFieldsStore: StoreOf<DocumentCustomFieldsReducer> {
        store.scope(state: \.readOnlyCustomFields, action: \.readOnlyCustomFields)
    }

    @ViewBuilder
    private func header() -> some View {
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
    }

    @ViewBuilder
    private func content() -> some View {
        switch store.section {
        case .content:
            contentSection()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .customFields:
            if store.isCustomFieldsEditable {
                DocumentFormCustomFieldsView(store: store)
            } else {
                DocumentCustomFieldsView(store: readOnlyCustomFieldsStore)
            }
        case .details:
            detailsSection()
        case .history:
            DocumentHistoryView(store: historyStore)
        case .metadata:
            DocumentMetadataView(store: metadataStore)
        case .notes:
            DocumentNotesView(store: notesStore, isReadOnly: store.isOfflineSnapshot)
        }
    }

    // Only called when `hasBottom` says there is something to show.
    @ViewBuilder
    private func bottom() -> some View {
        if store.section == .notes {
            DocumentNoteComposerView(store: notesStore)
        } else {
            buttons()
        }
    }

    @ViewBuilder
    private func sectionMenu() -> some View {
        Menu {
            Picker("", selection: $store.section) {
                // Sections the user cannot open drop out here too. Gating the entrance one screen
                // earlier is not enough: this picker is a second way into every section.
                ForEach(store.visibleSections, id: \.self) {
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
    private func detailsSection() -> some View {
        VStack(spacing: .x3) {
            TitleField(text: $store.input.title)
            ASNField(
                isLoading: $store.isLoadingNextArchiveSerialNumber,
                text: $store.input.archiveSerialNumber,
                getNextButtonTapped: { send(.getNextArchiveSerialNumberButtonTapped) }
            )
            DateField(
                title: .createdDate,
                value: $store.input.createdDate,
                suggestions: .constant([])
            )
            if store.canViewCorrespondent {
                correspondentField()
            }
            if store.canViewDocumentType {
                documentTypeField()
            }
            if store.canViewStoragePath {
                storagePathField()
            }
            if store.canViewTag {
                tagsField()
            }
        }
        .frame(maxWidth: .infinity)
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
        } else if let content = store.content {
            if store.isEditable {
                // Not m3SurfaceBright, which the smaller fields use: it is the *brightest* surface,
                // so against m3Surface it is invisible in light mode and a stark slab in dark. Over
                // an area this size the outline is what says "editable", not the fill.
                TextEditor(text: contentBinding())
                    .accessibilityLabel(.content)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    // Margins rather than padding: padding insets the whole text view, scroll
                    // indicator included, while these inset only the text and leave the indicator
                    // at the box's edge. It keeps a vertical inset of its own so it does not run
                    // into the rounded corners.
                    .contentMargins(.x3, for: .scrollContent)
                    .contentMargins(.vertical, .x3, for: .scrollIndicators)
                    .background(Color.m3SurfaceContainerLow)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                            .stroke(Color.m3OutlineVariant, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            } else if !content.isEmpty {
                // Selectable: reading a scan and copying a reference number out of it is the same
                // trip.
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
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }

    private func contentBinding() -> Binding<String> {
        Binding(
            get: { store.content ?? "" },
            set: { $store.content.wrappedValue = $0 }
        )
    }

    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                send(.resetButtonTapped)
            } label: {
                Text(.reset)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
            .disabled(!store.isModified || store.isUpdating)

            Button {
                send(.saveButtonTapped)
            } label: {
                Text(.save)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isUpdating))
            .disabled(!store.isModified || store.input.hasInvalidCustomField)
        }
    }

    @ViewBuilder
    private func correspondentField() -> some View {
        SingleSelectField(
            options: store.correspondents.elements,
            selection: $store.input.correspondent,
            title: .correspondent,
            onCreate: store.canCreateCorrespondent ? { send(.createCorrespondentButtonTapped) } : nil
        )
        .sheet(
            item: $store.scope(
                state: \.destination?.correspondentForm,
                action: \.destination.correspondentForm
            )
        ) { store in
            CorrespondentFormView(store: store)
        }
    }

    @ViewBuilder
    private func documentTypeField() -> some View {
        SingleSelectField(
            options: store.documentTypes.elements,
            selection: $store.input.documentType,
            title: .documentType,
            onCreate: store.canCreateDocumentType ? { send(.createDocumentTypeButtonTapped) } : nil
        )
        .sheet(
            item: $store.scope(
                state: \.destination?.documentTypeForm,
                action: \.destination.documentTypeForm
            )
        ) { store in
            DocumentTypeFormView(store: store)
        }
    }

    @ViewBuilder
    private func storagePathField() -> some View {
        SingleSelectField(
            options: store.storagePaths.elements,
            selection: $store.input.storagePath,
            title: .storagePath,
            onCreate: store.canCreateStoragePath ? { send(.createStoragePathButtonTapped) } : nil
        )
        .sheet(
            item: $store.scope(
                state: \.destination?.storagePathForm,
                action: \.destination.storagePathForm
            )
        ) { store in
            StoragePathFormView(store: store)
        }
    }

    @ViewBuilder
    private func tagsField() -> some View {
        MultiSelectField(
            options: store.tags.elements,
            selection: $store.input.tags,
            title: .tags,
            onCreate: store.canCreateTag ? { send(.createTagButtonTapped) } : nil,
            fieldItem: {
                Text($0.description)
                    .capsule(
                        backgroundColor: Color(hex: $0.color),
                        foregroundColor: Color(hex: $0.textColor)
                    )
            },
            optionsItem: {
                Text($0.description)
                    .capsule(
                        backgroundColor: Color(hex: $0.color),
                        foregroundColor: Color(hex: $0.textColor)
                    )
            },
        )
        .sheet(
            item: $store.scope(
                state: \.destination?.tagForm,
                action: \.destination.tagForm
            )
        ) { store in
            TagFormView(store: store)
        }
    }
}

#Preview {
    NavigationStack {
        DocumentSheetView(
            store: Store(
                initialState: DocumentSheetReducer.State.testValue(),
                reducer: {
                    DocumentSheetReducer()
                }
            )
        )
    }
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
