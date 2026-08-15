import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import Dependencies
import DocumentTypesFeature
import SavedViewsFeature
import StoragePathsFeature
import SwiftUI
import TagsFeature

@ViewAction(for: DocumentFilterReducer.self)
struct DocumentFilterView: View {
    var body: some View {
        Sheet {
            SheetHeader(
                title: savedViewsMenu,
                left: leftHeader,
                right: rightHeader
            )
        } content: {
            VStack(spacing: .x3) {
                searchField()
                correspondentField()
                documentTypeField()
                storagePathField()
                tagField()
                dateField()
                sortField()
            }
            .frame(maxWidth: .infinity)
        } bottom: {
            buttons()
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.savedViewForm,
                action: \.destination.savedViewForm
            )
        ) { store in
            SavedViewFormView(store: store)
                .presentationDetents([.large])
        }
    }

    @Bindable
    var store: StoreOf<DocumentFilterReducer>

    @ViewBuilder
    private func correspondentField() -> some View {
        DocumentFilterGenericValueField(
            rule: store.input.correspondent.rule,
            selection: store.input.correspondent.selection,
            systemImage: "person.circle",
            title: .correspondent
        )
        .onTapGesture {
            send(.correspondentButtonTapped)
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.correspondentList,
                action: \.destination.correspondentList
            )
        ) { store in
            DocumentFilterGenericValueListView(
                store: store,
                title: .correspondent
            )
            .presentationDetents([.sheet])
        }
    }

    @ViewBuilder
    private func documentTypeField() -> some View {
        DocumentFilterGenericValueField(
            rule: store.input.documentType.rule,
            selection: store.input.documentType.selection,
            systemImage: "document.circle",
            title: .documentType
        )
        .onTapGesture {
            send(.documentTypeButtonTapped)
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.documentTypeList,
                action: \.destination.documentTypeList
            )
        ) { store in
            DocumentFilterGenericValueListView(
                store: store,
                title: .correspondent
            )
            .presentationDetents([.sheet])
        }
    }

    @ViewBuilder
    private func storagePathField() -> some View {
        DocumentFilterGenericValueField(
            rule: store.input.storagePath.rule,
            selection: store.input.storagePath.selection,
            systemImage: "folder.circle",
            title: .storagePath
        )
        .onTapGesture {
            send(.storagePathButtonTapped)
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.storagePathList,
                action: \.destination.storagePathList
            )
        ) { store in
            DocumentFilterGenericValueListView(
                store: store,
                title: .storagePath
            )
            .presentationDetents([.sheet])
        }
    }

    @ViewBuilder
    private func dateField() -> some View {
        DocumentFilterDateField(date: store.input.date)
            .onTapGesture {
                send(.dateButtonTapped)
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.date,
                    action: \.destination.date
                )
            ) { store in
                DocumentFilterDateView(store: store)
                    .presentationDetents([.sheet])
            }
    }

    @ViewBuilder
    private func searchField() -> some View {
        DocumentFilterSearchField(
            asnType: store.input.asnType,
            onViewAction: send,
            searchType: store.input.searchType,
            searchValue: $store.input.searchValue
        )
    }

    @ViewBuilder
    private func sortField() -> some View {
        DocumentFilterSortField(
            direction: store.input.sort.direction,
            field: store.input.sort.field,
            onViewAction: send
        )
    }

    @ViewBuilder
    private func tagField() -> some View {
        DocumentFilterTagField(
            rule: store.input.tag.rule,
            selection: store.input.tag.selection
        )
        .onTapGesture {
            send(.tagButtonTapped)
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.tagList,
                action: \.destination.tagList
            )
        ) { store in
            DocumentFilterTagListView(store: store)
                .presentationDetents([.sheet])
        }
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

            Button {
                send(.applyButtonTapped)
            } label: {
                Text(.apply)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary())
        }
    }

    @ViewBuilder
    private func leftHeader() -> some View {
        Button {
            send(.closeButtonTapped)
        } label: {
            Image(systemName: "xmark")
                .accessibilityLabel(.close)
        }
    }

    @ViewBuilder
    private func rightHeader() -> some View {
        saveMenu()
    }

    @ViewBuilder
    private func savedViewsMenu() -> some View {
        ZStack {
            title()
            Menu {
                Button {
                    send(.savedViewButtonTapped(nil))
                } label: {
                    HStack(spacing: .x4) {
                        Image(systemName: store.savedView == nil ? "checkmark.circle.fill" : "circle")
                        Text(.allDocuments)
                    }
                }

                Divider()

                ForEach(store.savedViews) { savedView in
                    Button {
                        send(.savedViewButtonTapped(savedView))
                    } label: {
                        HStack(spacing: .x4) {
                            Image(systemName: store.savedView?.id == savedView.id ? "checkmark.circle.fill" : "circle")
                            Text(savedView.name)
                        }
                    }
                }
            } label: {
                title().opacity(0)
            }
        }
    }

    @ViewBuilder
    private func saveMenu() -> some View {
        Menu {
            Button {
                send(.saveAsButtonTapped)
            } label: {
                Text(.saveAs)
            }

            if store.savedView != nil {
                Button {
                    send(.saveButtonTapped)
                } label: {
                    Text(.save)
                }
                .disabled(!store.isModified)
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
                .accessibilityLabel(.moreOptions)
        }
    }

    @ViewBuilder
    private func title() -> some View {
        HStack(spacing: .x3) {
            Text(store.sheetTitle)
                .capsule(
                    backgroundColor: .m3SurfaceBright,
                    font: .body,
                    foregroundColor: .m3Primary
                )
                .overlay(alignment: .topTrailing) {
                    if store.isModified {
                        Circle()
                            .accessibilityLabel(.hasUnsavedChanges)
                            .foregroundStyle(Color.m3PrimaryContainer)
                            .frame(width: .x3, height: .x3)
                            .offset(x: .x3)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        DocumentFilterView(
            store: Store(
                initialState: DocumentFilterReducer.State.testValue(),
                reducer: {
                    DocumentFilterReducer()
                }
            )
        )
    }
}
