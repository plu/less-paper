#if DEBUG
import ApiInterface
import Foundation

// Resolves the thumbnail URL the app builds - /api/documents/<id>/thumb/ - to a file downloaded
// into Screenshots/Thumbnails. The id is read back out of the URL rather than passed alongside it,
// so DocumentImage stays unaware that anything has been substituted.
enum SnapshotThumbnails {

    static func data(for url: URL) -> Data? {
        guard let id = documentId(in: url) else {
            return nil
        }
        return SnapshotFixtures.thumbnail(for: id)
    }

    private static func documentId(in url: URL) -> Document.Id? {
        guard let match = url.path().firstMatch(of: /documents\/(?<id>\d+)\/thumb/) else {
            return nil
        }
        guard let id = Int(match.id) else {
            return nil
        }
        return Document.Id(rawValue: id)
    }
}
#endif
