import ApiInterface
import Foundation
import MultipartFormDataKit

extension CreateDocumentInput {

    var formData: MultipartFormData.BuildResult {
        get throws {
            var parts: [MultipartFormData.PartParam] = [
                (
                    name: "created",
                    filename: nil,
                    mimeType: nil,
                    data: Data(String(DateFormatter.createdDate.string(from: createdDate)).utf8)
                ),

                (
                    name: "document",
                    filename: url.lastPathComponent,
                    mimeType: nil,
                    data: try Data(contentsOf: url)
                ),

                (
                    name: "title",
                    filename: nil,
                    mimeType: nil,
                    data: Data(title.utf8)
                )
            ]

            if let archiveSerialNumber {
                parts.append((
                    name: "archive_serial_number",
                    filename: nil,
                    mimeType: nil,
                    data: Data(String(archiveSerialNumber).utf8)
                ))
            }

            if let correspondent {
                parts.append((
                    name: "correspondent",
                    filename: nil,
                    mimeType: nil,
                    data: Data(String(correspondent).utf8)
                ))
            }

            if let documentType {
                parts.append((
                    name: "document_type",
                    filename: nil,
                    mimeType: nil,
                    data: Data(String(documentType).utf8)
                ))
            }

            if let storagePath {
                parts.append((
                    name: "storage_path",
                    filename: nil,
                    mimeType: nil,
                    data: Data(String(storagePath).utf8)
                ))
            }

            for tag in tags {
                parts.append((
                    name: "tags",
                    filename: nil,
                    mimeType: nil,
                    data: Data(String(tag).utf8)
                ))
            }

            return try MultipartFormData.Builder.build(
                with: parts,
                willSeparateBy: RandomBoundaryGenerator.generate()
            )
        }
    }
}
