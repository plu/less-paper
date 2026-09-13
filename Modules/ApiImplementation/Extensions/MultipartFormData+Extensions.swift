import Foundation
import MultipartFormDataKit

extension MultipartFormData {

    // MultipartFormDataKit's own `Builder` puts every name and filename through
    // `addingPercentEncoding`. RFC 7578 allows that, but paperless-ngx stores the `filename`
    // parameter verbatim without undoing it, so a document picked as "Sonos One.pdf" arrives as
    // "Sonos%20One.pdf" and keeps that name forever. Assembling the parts here sends the values
    // unencoded, which is what browsers do and what the server expects.
    //
    // `asPercentEncoded` is the library's escape hatch for a value that is already in its final
    // header form - handing it a raw string is what stops the encoding.
    static func build(
        parts: [PartParam],
        boundary: String
    ) throws -> BuildResult {
        let formData = MultipartFormData(
            uniqueAndValidLengthBoundary: boundary,
            body: parts.map { part in
                Part(
                    contentDisposition: ContentDisposition(
                        name: Name(asPercentEncoded: part.name),
                        filename: part.filename.map { Filename(asPercentEncoded: $0) }
                    ),
                    contentType: part.mimeType.map { ContentType(representing: $0) },
                    content: part.data
                )
            }
        )

        switch formData.asData() {
        case let .valid(body):
            return BuildResult(
                contentType: formData.header.value,
                body: body
            )

        case let .invalid(because: error):
            throw error
        }
    }
}
