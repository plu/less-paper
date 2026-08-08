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
        Sheet {
            SheetHeader(title: .editDocument, left: {
                Button {
                    send(.closeButtonTapped)
                } label: {
                    Image(systemName: "xmark")
                        .accessibilityLabel(.close)
                }
            })
        } content: {
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
        } bottom: {
            buttons()
        }
    }

    @Bindable
    var store: StoreOf<DocumentFormReducer>

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
            .disabled(!store.isModified)
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
