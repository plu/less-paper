import Foundation
import Tagged

public struct CreateShareLinkInput: Codable, Equatable, Sendable {

    public let document: Document.Id

    public let expiration: Date?

    public let fileVersion: ShareLink.FileVersion

    public init(
        document: Document.Id,
        expiration: Date?,
        fileVersion: ShareLink.FileVersion
    ) {
        self.document = document
        self.expiration = expiration
        self.fileVersion = fileVersion
    }
}

public extension CreateShareLinkInput {

    // The shared encoder writes dates as yyyy-MM-dd, which would turn a link expiring in an hour
    // into one expiring at midnight. The expiration is written as a full ISO 8601 timestamp, and
    // as an explicit null for a link that never expires, because a missing key is not the same.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(document, forKey: .document)
        if let expiration {
            try container.encode(expiration.formatted(.iso8601), forKey: .expiration)
        } else {
            try container.encodeNil(forKey: .expiration)
        }
        try container.encode(fileVersion, forKey: .fileVersion)
    }

    static func testValue(
        document: Document.Id = 1,
        expiration: Date? = nil,
        fileVersion: ShareLink.FileVersion = .archive
    ) -> Self {
        .init(
            document: document,
            expiration: expiration,
            fileVersion: fileVersion
        )
    }
}
