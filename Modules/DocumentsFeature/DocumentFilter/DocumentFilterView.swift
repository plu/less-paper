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
                customFieldField()
                dateField()
                sortField()
            }
            .frame(maxWidth: .infinity)
        }
        // `safeAreaInset` rather than an overlay: the capsule floats over the scroll view either
        // way, but this also insets the scrollable content by its height, so the last field can be
        // scrolled clear of it instead of sitting underneath.
        .safeAreaInset(edge: .bottom, spacing: .x0) {
            DocumentFilterMatchCountView()
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
    private func customFieldField() -> some View {
        DocumentFilterCustomFieldField(
            fields: store.customFields,
            query: store.input.customFieldQuery
        )
        .onTapGesture {
            send(.customFieldButtonTapped)
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.customFieldQuery,
                action: \.destination.customFieldQuery
            )
        ) { store in
            CustomFieldQueryCardsView(store: store)
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

    // Drops writes that carry the value the store already holds. SwiftUI makes one as the sheet
    // tears down, by which point the presentation state is gone — the action then lands on an
    // absent destination and ComposableArchitecture reports a runtime issue. It makes another on
    // presentation, which cost a 400ms debounce for a search that had not changed.
    var searchValueBinding: Binding<String> {
        Binding(
            get: { store.input.searchValue },
            set: {
                guard $0 != store.input.searchValue else {
                    return
                }
                send(.searchValueChanged($0))
            }
        )
    }

    @ViewBuilder
    private func searchField() -> some View {
        DocumentFilterSearchField(
            asnType: store.input.asnType,
            onViewAction: send,
            searchType: store.input.searchType,
            searchValue: searchValueBinding
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
    private func leftHeader() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    @ViewBuilder
    private func rightHeader() -> some View {
        optionsMenu()
    }

    @ViewBuilder
    private func optionsMenu() -> some View {
        Menu {
            if store.savedView != nil {
                Button {
                    send(.saveButtonTapped)
                } label: {
                    Text(.save)
                }
                .disabled(!store.isModified)
            }

            Button {
                send(.saveAsButtonTapped)
            } label: {
                Text(.saveAs)
            }

            Divider()

            Button(role: .destructive) {
                send(.resetButtonTapped)
            } label: {
                Text(.reset)
            }
            .disabled(!store.isModified)
        } label: {
            Image(systemName: "ellipsis")
                .sheetHeaderTapTarget()
                .accessibilityLabel(.moreOptions)
        }
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
