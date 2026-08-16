import ApiInterface
import Dependencies
import Foundation

extension Document {

    func download(server: Server) async throws -> (data: Data, url: URL) {
        @Dependency(\.downloadDocument.execute)
        var downloadDocument

        let data = try await downloadDocument(id, server)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return (data: data, url: url)
    }
}
