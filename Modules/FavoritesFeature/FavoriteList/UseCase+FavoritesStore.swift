import ApiInterface
import ComposableArchitecture
import Foundation

// The five fetches the document detail screen makes on the way to displaying a document, answered
// from the favorite instead of the server. Pointing the existing screen at these is what makes it
// readable with no connection without a second implementation of it.
//
// Reads only. The writes that screen can make — updateDocument, createNote, deleteNote,
// getNextArchiveSerialNumber, and the form picker's getDocuments — still go to the server, and are
// gated elsewhere rather than answered here.

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

extension GetDocumentUseCase {

    // Safe to answer with the stored copy only because `SaveFavoriteUseCase` fetches this endpoint
    // rather than keeping the list document it was handed: the list copy's `content` is truncated,
    // and serving that here would show a preview of the text as if it were all of it.
    static var favoritesStore: Self {
        Self(execute: { id, server in
            @Shared(.favorites(server))
            var favorites: IdentifiedArrayOf<FavoriteDocument>

            guard let document = favorites[id: id]?.document else {
                throw FavoritesStoreError.notStored
            }
            return document
        })
    }
}

extension GetDocumentsByIdsUseCase {

    // Whichever of the requested ids are themselves favorites. A linked document that was never
    // favorited cannot resolve offline; showing the ones that are beats failing the whole section.
    static var favoritesStore: Self {
        Self(execute: { input, server in
            @Shared(.favorites(server))
            var favorites: IdentifiedArrayOf<FavoriteDocument>

            return input.ids.compactMap { favorites[id: $0]?.document }
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
