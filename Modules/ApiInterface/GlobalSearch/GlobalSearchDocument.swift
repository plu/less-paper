import Foundation
import Tagged

// Not `Document`: Paperless-ngx 3.4 serialises search hits with only `id`, `title` and `created`,
// and decoding the full model failed the whole response on the first missing field. Older servers
// still send everything, which this simply ignores.
public struct GlobalSearchDocument: Decodable, Equatable, Hashable, Identifiable, Sendable {

    public let created: Date

    public let id: Document.Id

    public let title: String

    public init(created: Date, id: Document.Id, title: String) {
        self.created = created
        self.id = id
        self.title = title
    }

    private enum CodingKeys: String, CodingKey {
        case created, createdDate, id, title
    }

    // Same reading as `Document`: `created_date` is date-only on every version that sends it,
    // where `created` was a local-midnight datetime on API 8 and can render as the day before.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        created = try container.decodeIfPresent(Date.self, forKey: .createdDate)
            ?? container.decode(Date.self, forKey: .created)
        id = try container.decode(Document.Id.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
    }
}

public extension GlobalSearchDocument {

    static func testValue(
        created: Date = .testValue(),
        id: Document.Id = 1,
        title: String = "Invoice"
    ) -> Self {
        .init(created: created, id: id, title: title)
    }
}
