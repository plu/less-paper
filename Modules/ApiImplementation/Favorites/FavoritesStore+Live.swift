import ApiInterface
import Dependencies
import Foundation

extension FavoritesStore: @retroactive DependencyKey {

    public static let liveValue = Self(
        deleteAll: { server in
            try? FileManager.default.removeItem(at: directory(server))
        },
        deletePDF: { id, server in
            try? FileManager.default.removeItem(at: url(id, server))
        },
        pdfURL: { id, server in
            url(id, server)
        },
        totalByteCount: { server in
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: directory(server),
                includingPropertiesForKeys: [.fileSizeKey]
            )) ?? []

            return urls.reduce(0) { total, url in
                total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        },
        writePDF: { data, id, server in
            let directory = directory(server)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // Written beside the destination and moved onto it: a download killed mid-flight must
            // not leave a truncated file that later reads as a corrupt PDF.
            let temporary = directory.appending(component: "\(id.rawValue).pdf.partial")
            try data.write(to: temporary, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url(id, server), withItemAt: temporary)

            return data.count
        }
    )

    private static func directory(_ server: Server) -> URL {
        URL.applicationGroupDirectory
            .appending(component: "Favorites")
            .appending(component: "\(server.id)")
    }

    private static func url(_ id: Document.Id, _ server: Server) -> URL {
        directory(server).appending(component: "\(id.rawValue).pdf")
    }
}
