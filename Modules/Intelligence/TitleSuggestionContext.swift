import Foundation

// Deliberately not a `Document`: keeping the API-layer types out is what lets this module stay off
// `ApiInterface`, and it is the caller's job to format dates and resolve entity names.
public struct TitleSuggestionContext: Equatable, Sendable {

    // The model's context window is about 4k tokens and a scanned multi-page document runs to tens
    // of thousands of characters, so something has to give. A document's identifying information is
    // almost always on its first page.
    public static let contentLimit = 2000

    public struct CustomFieldValue: Equatable, Sendable {

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }

        public let label: String

        public let value: String
    }

    public init(
        archiveSerialNumber: String? = nil,
        content: String = "",
        correspondent: String? = nil,
        createdDate: String = "",
        customFields: [CustomFieldValue] = [],
        documentType: String? = nil,
        storagePath: String? = nil,
        tags: [String] = [],
        title: String = ""
    ) {
        self.archiveSerialNumber = archiveSerialNumber
        self.content = content
        self.correspondent = correspondent
        self.createdDate = createdDate
        self.customFields = customFields
        self.documentType = documentType
        self.storagePath = storagePath
        self.tags = tags
        self.title = title
    }

    public let archiveSerialNumber: String?

    public let content: String

    public let correspondent: String?

    public let createdDate: String

    public let customFields: [CustomFieldValue]

    public let documentType: String?

    public let storagePath: String?

    public let tags: [String]

    public let title: String

    // The user prompt. Instructions live on the session, not here.
    // EXPERIMENT (2026-09-08): the document text alone, with none of the metadata this type still
    // carries. Revert this commit to put the metadata back. The other properties are deliberately
    // left populated so the diff is one method and the caller is untouched.
    public var prompt: String {
        Self.truncated(content)
    }

    static func truncated(_ content: String) -> String {
        guard content.count > contentLimit else {
            return content
        }

        let clipped = content.prefix(contentLimit)

        guard let boundary = clipped.lastIndex(where: \.isWhitespace) else {
            // A single unbroken run of characters — OCR of a barcode, say. There is no boundary to
            // find, so a hard cut is the only option.
            return String(clipped) + "…"
        }

        return String(clipped[..<boundary]) + "…"
    }
}
