import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import DocumentsFeature
import SwiftUI

@ViewAction(for: FavoriteRowReducer.self)
struct FavoriteRowView: View {

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
        .frame(maxWidth: .infinity)
        .background(Color.m3SurfaceContainer)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .onTapGesture { send(.rowTapped) }
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .swipeActions {
            Button(role: .destructive) {
                send(.unfavoriteButtonTapped)
            } label: {
                Label(.unfavorite, systemImage: "heart.slash")
            }
        }
    }

    var store: StoreOf<FavoriteRowReducer>

    @ViewBuilder
    private func detailsView() -> some View {
        DocumentRowContent(
            document: store.document,
            server: store.server,
            titleLineLimit: titleLineLimit
        )
    }

    @ViewBuilder
    private func imageView() -> some View {
        FavoriteThumbnail(url: pdfURL, size: imageSize, storedAt: store.favorite.storedAt)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                tagsView()
            }
            .overlay(alignment: .topLeading) {
                unavailableBadge()
            }
            .padding(.top, sizeCategory >= breakpoint ? .x4 : .x0)
            .padding(.horizontal, sizeCategory >= breakpoint ? .x4 : .x0)
    }

    @ViewBuilder
    private func tagsView() -> some View {
        DocumentRowTags(tags: tags, height: imageSize.height)
    }

    @ViewBuilder
    private func unavailableBadge() -> some View {
        if store.favorite.isUnavailable {
            Text(.favoriteUnavailable)
                .capsule(backgroundColor: .m3Error, font: .footnote, foregroundColor: .m3OnError)
                .padding(.x3)
        }
    }

    private let breakpoint = ContentSizeCategory.extraLarge

    private var imageSize: CGSize {
        CGSize(width: 134 * scaleFactor, height: 190 * scaleFactor)
    }

    private var pdfURL: URL {
        @Dependency(\.favoritesStore.pdfURL) var pdfURL
        return pdfURL(store.favorite.id, store.server)
    }

    private var tags: [Tag] {
        store.document.tags.compactMap { $0.get(store.server) }
    }

    // Mirrors DocumentRowReducer.State.titleLineLimit: one less line per detail row the document
    // carries, so a busy row still fits inside the same thumbnail height.
    private var titleLineLimit: Int {
        let document = store.document
        var titleLineLimit = 6
        if document.archiveSerialNumber != nil {
            titleLineLimit -= 1
        }
        if document.documentType != nil {
            titleLineLimit -= 1
        }
        if document.storagePath != nil {
            titleLineLimit -= 1
        }
        return titleLineLimit
    }

    @ScaledMetric
    private var scaleFactor = 1.0

    @Environment(\.sizeCategory)
    private var sizeCategory
}

#Preview {
    List {
        FavoriteRowView(
            store: Store(
                initialState: FavoriteRowReducer.State(favorite: .testValue(), server: .testValue()),
                reducer: {
                    FavoriteRowReducer()
                }
            )
        )

        FavoriteRowView(
            store: Store(
                initialState: FavoriteRowReducer.State(
                    favorite: .testValue(isUnavailable: true),
                    server: .testValue()
                ),
                reducer: {
                    FavoriteRowReducer()
                }
            )
        )
    }
    .background(Color.m3SurfaceContainerLowest)
    .listStyle(.plain)
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden)
}
