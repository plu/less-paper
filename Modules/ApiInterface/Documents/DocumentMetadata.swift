import Foundation

public struct DocumentMetadata: Codable, Equatable, Hashable, Sendable {

    public let archiveChecksum: String?

    public let archiveMediaFilename: String?

    public let archiveSize: Int?

    public let hasArchiveVersion: Bool

    // The server's own name for it. Spelling it `language` would buy one nicer property in exchange
    // for a CodingKeys enum listing every key, to be maintained whenever the payload grows.
    public let lang: String?

    public let mediaFilename: String?

    public let originalChecksum: String?

    // One word in this payload, unlike the documents endpoint's `original_file_name` that
    // `Document.originalFileName` decodes. The two endpoints disagree; the models follow their own.
    public let originalFilename: String?

    public let originalMimeType: String?

    public let originalSize: Int?

    public init(
        archiveChecksum: String?,
        archiveMediaFilename: String?,
        archiveSize: Int?,
        hasArchiveVersion: Bool,
        lang: String?,
        mediaFilename: String?,
        originalChecksum: String?,
        originalFilename: String?,
        originalMimeType: String?,
        originalSize: Int?
    ) {
        self.archiveChecksum = archiveChecksum
        self.archiveMediaFilename = archiveMediaFilename
        self.archiveSize = archiveSize
        self.hasArchiveVersion = hasArchiveVersion
        self.lang = lang
        self.mediaFilename = mediaFilename
        self.originalChecksum = originalChecksum
        self.originalFilename = originalFilename
        self.originalMimeType = originalMimeType
        self.originalSize = originalSize
    }
}

public extension DocumentMetadata {

    var isEmpty: Bool {
        [
            archiveChecksum,
            archiveMediaFilename,
            lang,
            mediaFilename,
            originalChecksum,
            originalFilename,
            originalMimeType
        ].allSatisfy { $0?.isEmpty ?? true } && archiveSize == nil && originalSize == nil
    }
}

public extension DocumentMetadata {

    static func testValue(
        archiveChecksum: String? = "bbafb1f0061d5860eb3969f6c26d05c91eedb0fb827bfe497b0fcac0a9f593a0",
        archiveMediaFilename: String? = "0000044.pdf",
        archiveSize: Int? = 578_585,
        hasArchiveVersion: Bool = true,
        lang: String? = "en",
        mediaFilename: String? = "0000044.pdf",
        originalChecksum: String? = "65990b5f69b2fcc4e24bf93340721ea8cfef2f36a0f2b87deb5b80344caa861f",
        originalFilename: String? = "TonieBox.pdf",
        originalMimeType: String? = "application/pdf",
        originalSize: Int? = 335_237
    ) -> Self {
        .init(
            archiveChecksum: archiveChecksum,
            archiveMediaFilename: archiveMediaFilename,
            archiveSize: archiveSize,
            hasArchiveVersion: hasArchiveVersion,
            lang: lang,
            mediaFilename: mediaFilename,
            originalChecksum: originalChecksum,
            originalFilename: originalFilename,
            originalMimeType: originalMimeType,
            originalSize: originalSize
        )
    }
}
