import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import Dependencies
import DocumentTypesFeature
import StoragePathsFeature
import SwiftUI
import TagsFeature

@ViewAction(for: DocumentFormReducer.self)
struct DocumentFormView: View {
    var body: some View {
        // The notes list spans the sheet edge to edge and insets its own rows instead, so its
        // scroll indicator sits at the sheet's edge and rows clip there rather than 16pt short.
        Sheet(
            isScrollingEnabled: store.section == .details || store.section == .customFields,
            padding: store.section == .notes ? 0 : .x4
        ) {
            SheetHeader(
                title: .editDocument,
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
            case .customFields:
                DocumentFormCustomFieldsView(store: store)
            case .details:
                detailsSection()
            case .content:
                contentSection()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notes:
                DocumentNotesView(store: notesStore)
            }
        } bottom: {
            // The composer takes the slot Reset and Save vacate: nothing in the notes section is
            // staged, so neither button would have anything to act on.
            switch store.section {
            case .content, .customFields, .details:
                buttons()
            case .notes:
                DocumentNoteComposerView(store: notesStore)
            }
        }
        .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentFormReducer>

    private var notesStore: StoreOf<DocumentNotesReducer> {
        store.scope(state: \.notes, action: \.notes)
    }

    @ViewBuilder
    private func sectionMenu() -> some View {
        Menu {
            Picker("", selection: $store.section) {
                ForEach(DocumentFormSection.allCases, id: \.self) {
                    Text($0.description).tag($0)
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
            correspondentField()
            documentTypeField()
            storagePathField()
            tagsField()
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
        } else if store.content == nil {
            ProgressView()
                .controlSize(.large)
        } else {
            // Not m3SurfaceBright, which the smaller fields use: it is the *brightest* surface, so
            // against m3Surface it is invisible in light mode and a stark slab in dark. Over an
            // area this size the outline is what says "editable", not the fill.
            TextEditor(text: contentBinding())
                .accessibilityLabel(.content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.x3)
                .background(Color.m3SurfaceContainerLow)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                        .stroke(Color.m3OutlineVariant, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
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
            onCreate: { send(.createCorrespondentButtonTapped) }
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
            onCreate: { send(.createDocumentTypeButtonTapped) }
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
            onCreate: { send(.createStoragePathButtonTapped) }
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
            onCreate: { send(.createTagButtonTapped) },
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
        DocumentFormView(
            store: Store(
                initialState: DocumentFormReducer.State.testValue(),
                reducer: {
                    DocumentFormReducer()
                }
            )
        )
    }
}
