import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import DocumentTypesFeature
import QuickLook
import StoragePathsFeature
import SwiftUI
import TagsFeature

@ViewAction(for: ShareFormReducer.self)
struct ShareFormView: View {

    var body: some View {
        contentView()
            .task { await send(.onAppear).finish() }
    }

    init(store: StoreOf<ShareFormReducer>) {
        self.store = store
    }

    @Bindable
    var store: StoreOf<ShareFormReducer>

    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                send(.skipButtonTapped)
            } label: {
                Text(.skip)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
            .frame(maxWidth: .infinity)
            .disabled(store.isImporting)

            Button {
                send(.importButtonTapped)
            } label: {
                Text(.import)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isImporting))
            .disabled(store.isLocked)
        }
    }

    @ViewBuilder
    private func contentView() -> some View {
        Sheet {
            Text(.header(
                fileNumber: store.currentIndex + 1,
                totalNumberOfFiles: store.files.count
            ))
        } content: {
            VStack(spacing: .x3) {
                imageView()
                serverField()
                TitleField(text: $store.input.title)
                correspondentField()
                documentTypeField()
                tagsField()
                storagePathField()
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
            }
            .frame(maxWidth: .infinity)
        } contentOverlay: {
            if store.isLocked {
                unlockView()
            }
        } bottom: {
            buttons()
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
    private func imageView() -> some View {
        Group {
            if let image = store.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 114, height: 154)
                    .clipped()
                    .shadow(radius: 5)
            } else {
                Image(systemName: "richtext.page")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 114, height: 154)
                    .foregroundStyle(Color.m3Outline)
            }
        }
        .quickLookPreview($store.quickLookPreview)
        .onTapGesture { store.quickLookPreview = store.files[store.currentIndex] }
    }

    @ViewBuilder
    private func serverField() -> some View {
        if store.servers.count > 1 {
            SingleSelectField(
                options: store.servers.elements,
                selection: $store.server,
                title: .server
            )
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

    @ViewBuilder
    private func unlockView() -> some View {
        ZStack(alignment: .center) {
            Color.m3Surface

            VStack(spacing: .x4) {
                Spacer()

                TitleField(text: $store.input.title)

                Field(.password) {
                    SecureField(String(localized: .password), text: $store.input.password)
                        .textFieldStyle(.plain)
                }
                .accessibilityLabel(.password)

                Toggle(isOn: $store.input.shouldRememberPassword) {
                    Text(.rememberPassword)
                }
                .tint(Color.m3Primary)
                .padding(.horizontal, .x3)

                Text(.fileLocked)
                    .font(.footnote)
                    .foregroundStyle(Color.m3OnSurface)
                    .padding(.x3)

                Button {
                    send(.unlockButtonTapped)
                } label: {
                    Text(.unlock)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())

                Spacer()
            }
            .padding(.x4)
        }
    }

    @Environment(\.dismiss)
    private var dismiss
}
