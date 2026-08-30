#if DEBUG
import ApiInterface
import Foundation

// Which documents the screenshots show, and in which order.
//
// The same documents in every language. Only the tags, document types and storage paths are
// translated - see SnapshotNames. The German-language documents in the seed are generated filler
// pages: their thumbnails are a title on an empty sheet, which photographs as a blank rectangle
// next to a real manual. A shelf of appliance manuals reads the same in both languages, and these
// all have a real PDF in docker/data.
extension SnapshotConfiguration.Corpus {

    // The order shown, because the stub returns these as they are. The first is the document the
    // view and edit screenshots open, so it leads: the capture taps the first row rather than
    // naming a document.
    static let documentIds: [Document.Id] = [8, 13, 12, 5, 4, 2, 1, 3]

    // The subset carrying the Inbox tag. Kept explicit rather than derived, because the inbox
    // screenshot wants a short, readable list rather than everything that happens to be tagged.
    static let inboxDocumentIds: [Document.Id] = [12, 5, 4]

    // The subset kept offline. Three rather than the whole corpus: the favorites screenshot is
    // about the feature, not the size of the shelf, and three rows fill an iPhone screen without
    // the last one being cut in half. They lead with the same document the view and edit screens
    // open, so a reader moving through the set keeps seeing the same manual.
    static let favoriteDocumentIds: [Document.Id] = [8, 13, 12]

    var documentIds: [Document.Id] {
        Self.documentIds
    }

    var favoriteDocumentIds: [Document.Id] {
        Self.favoriteDocumentIds
    }

    var inboxDocumentIds: [Document.Id] {
        Self.inboxDocumentIds
    }
}
#endif
