import ApiInterface
import Dependencies
import Foundation

extension FavoritesStore: @retroactive DependencyKey {

    public static let liveValue = Self(
        deleteAll: { server in
            try removeIfPresent(directory(server))
        },
        deletePDF: { id, server in
            try removeIfPresent(url(id, server))
        },
        pdfURL: { id, server in
            url(id, server)
        },
        totalByteCount: { server in
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: directory(server),
                includingPropertiesForKeys: [.fileSizeKey]
            )) ?? []

            // Only the PDFs. Summing whatever happens to be in the directory would let any stray
            // file inflate the number Settings shows as "storage used".
            return urls
                .filter { $0.pathExtension == "pdf" }
                .reduce(0) { total, url in
                    total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
        },
        writePDF: { data, id, server in
            try FileManager.default.createDirectory(at: directory(server), withIntermediateDirectories: true)

            // `.atomic` already writes to a temporary file and renames it into place, so a download
            // killed mid-flight cannot leave a truncated file that later reads as a corrupt PDF.
            // Doing that dance by hand would only add a partial file to leak when the rename throws.
            try data.write(to: url(id, server), options: .atomic)

            return data.count
        }
    )

    private static func directory(_ server: Server) -> URL {
        URL.applicationGroupDirectory
            .appending(component: "Favorites")
            .appending(component: "\(server.id)")
    }

    // Already gone is the outcome the caller wanted, so it is not an error. Anything else —
    // permissions, a busy volume — is, and must not be swallowed: a `try?` here would report a
    // favorite as removed while its bytes stayed on disk.
    private static func removeIfPresent(_ url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }

    private static func url(_ id: Document.Id, _ server: Server) -> URL {
        directory(server).appending(component: "\(id.rawValue).pdf")
    }
}
