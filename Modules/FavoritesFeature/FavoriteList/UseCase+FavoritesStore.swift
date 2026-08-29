import ApiInterface
import ComposableArchitecture
import Foundation

// The three fetches the document detail screen makes, answered from the favorite instead of the
// server. Pointing the existing screen at these is what makes it readable with no connection
// without a second implementation of it.

extension DownloadDocumentUseCase {

    static var favoritesStore: Self {
        Self(execute: { id, server in
            @Dependency(\.favoritesStore.pdfURL) var pdfURL

            @Shared(.favorites(server))
            var favorites: IdentifiedArrayOf<FavoriteDocument>

            guard favorites[id: id] != nil else {
                throw FavoritesStoreError.notStored
            }
            return try Data(contentsOf: pdfURL(id, server))
        })
    }
}

extension GetDocumentMetadataUseCase {

    static var favoritesStore: Self {
        Self(execute: { id, server in
            @Shared(.favorites(server))
            var favorites: IdentifiedArrayOf<FavoriteDocument>

            guard let metadata = favorites[id: id]?.metadata else {
                throw FavoritesStoreError.notStored
            }
            return metadata
        })
    }
}

extension GetNotesUseCase {

    // An empty array is the right answer for a document with no notes and for one that is not
    // stored alike: notes are part of the record, so anything the record does not carry is nothing
    // to show rather than an error to report.
    static var favoritesStore: Self {
        Self(execute: { id, server in
            @Shared(.favorites(server))
            var favorites: IdentifiedArrayOf<FavoriteDocument>

            return favorites[id: id]?.notes ?? []
        })
    }
}

enum FavoritesStoreError: Error, Equatable {
    case notStored
}

extension FavoritesStoreError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .notStored:
            String(localized: .notStoredOnDevice)
        }
    }
}
