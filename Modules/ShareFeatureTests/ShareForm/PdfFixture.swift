import Foundation
import PDFKit

enum PdfFixture {

    static func locked(name: String, password: String) throws -> URL {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        document.write(
            to: url,
            withOptions: [
                .ownerPasswordOption: password,
                .userPasswordOption: password
            ]
        )
        return url
    }

    static func unlocked(name: String) throws -> URL {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        document.write(to: url)
        return url
    }
}
