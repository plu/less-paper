import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import ImageFeature
import QuickLook
import SwiftUI

@ViewAction(for: DocumentRowReducer.self)
struct DocumentRowView: View {
    var body: some View {
        AdaptiveStack(
            breakpoint: breakpoint,
            horizontalAlignment: .center,
            horizontalSpacing: .x0,
            verticalSpacing: .x0
        ) {
            imageView()
            detailsView()
        }
        .sheet(item: $store.shareItem) { item in
            ShareSheet(url: item.url)
        }
        .frame(maxWidth: .infinity)
        .background(Color.m3SurfaceContainer)
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .onTapGesture { send(.rowTapped) }
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .contextMenu(menuItems: contextMenu)
        .opacity(store.isBusy ? 0.5 : 1.0)
        // After the opacity, so the spinner is not dimmed along with the row beneath it.
        .overlay { downloadProgressView() }
        .quickLookPreview($store.quickLookPreview)
        .sheet(
            item: $store.scope(state: \.destination?.documentForm, action: \.destination.documentForm)
        ) { store in
            DocumentFormView(store: store)
                .presentationDetents([.large])
        }
        .sheet(
            item: $store.scope(state: \.destination?.documentViewer, action: \.destination.documentViewer)
        ) { store in
            DocumentViewerView(store: store)
                .presentationDetents([.large])
        }
    }

    @Bindable
    var store: StoreOf<DocumentRowReducer>

    @ViewBuilder
    private func contextMenu() -> some View {
        // Favorite cannot sit in the A-Z run below: its label flips between "Favorite" and
        // "Unfavorite" as the state it reports changes, so an alphabetical position would move it
        // under the user's thumb between taps. Held first instead. No divider under it — it is one
        // of the reversible actions, and a divider would imply it is set apart the way Delete is.
        Button {
            send(.favoriteButtonTapped)
        } label: {
            Label(
                store.isFavorited ? .unfavorite : .favorite,
                systemImage: store.isFavorited ? "heart.fill" : "heart"
            )
        }

        Button {
            send(.editButtonTapped)
        } label: {
            Label(.edit, systemImage: "square.and.pencil")
        }

        Button {
            send(.previewButtonTapped)
        } label: {
            Label(.preview, systemImage: "eye")
        }

        DocumentShareMenu(documentId: store.document.id, server: store.server) {
            // A row has no file yet, so this asks for one: the download runs and the share sheet
            // follows it. The links below it need nothing downloaded.
            Button {
                send(.shareButtonTapped)
            } label: {
                Label(.document, systemImage: "doc")
            }
        }

        DocumentViewerMenu { send(.viewButtonTapped($0)) }

        // The reversible actions are A-Z; Delete is held out below the divider rather than taking
        // whatever row its initial earns it — alphabetically that is the top, one mistap from the
        // rest. Same shape as the bulk edit overflow menu.
        Divider()

        Button(role: .destructive) {
            send(.deleteButtonTapped)
        } label: {
            Label(.delete, systemImage: "trash")
        }
    }

    @ViewBuilder
    private func detailsView() -> some View {
        DocumentRowContent(
            document: store.document,
            server: store.server,
            titleLineLimit: store.titleLineLimit
        )
    }

    @ViewBuilder
    private func downloadProgressView() -> some View {
        if store.isDownloading {
            ProgressView()
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private func imageView() -> some View {
        DocumentImage(
            document: store.document.id,
            server: store.server,
            size: imageSize
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            tagsView()
        }
        .padding(.top, sizeCategory >= breakpoint ? .x4 : .x0)
        .padding(.horizontal, sizeCategory >= breakpoint ? .x4 : .x0)
    }

    @ViewBuilder
    private func tagsView() -> some View {
        DocumentRowTags(tags: store.tags, height: imageSize.height)
    }

    private let breakpoint = ContentSizeCategory.extraLarge

    private var imageSize: CGSize {
        CGSize(width: 134 * scaleFactor, height: 190 * scaleFactor)
    }

    @ScaledMetric
    private var scaleFactor = 1.0

    @Environment(\.sizeCategory)
    private var sizeCategory
}

#Preview {
    List {
        DocumentRowView(
            store: Store(
                initialState: DocumentRowReducer.State.testValue(),
                reducer: {
                    DocumentRowReducer()
                }
            )
        )

        DocumentRowView(
            store: Store(
                initialState: DocumentRowReducer.State.testValue(document: .testValue(tags: Array(repeating: 1, count: 20))),
                reducer: {
                    DocumentRowReducer()
                }
            )
        )

        ForEach(ContentSizeCategory.allCases, id: \.self) { sizeCategory in
            Section(String(describing: sizeCategory)) {
                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )
                .environment(\.sizeCategory, sizeCategory)
            }
        }
    }
    .background(Color.m3SurfaceContainerLowest)
    .listStyle(.plain)
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden)
}
