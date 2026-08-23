import Dependencies
import Foundation
import Tagged

public struct CustomField: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<CustomField, Int>

    public let dataType: CustomFieldDataType

    public let documentCount: Int

    public let extraData: CustomFieldExtraData?

    public let id: Id

    public let name: String

    public init(
        dataType: CustomFieldDataType,
        documentCount: Int,
        extraData: CustomFieldExtraData?,
        id: Id,
        name: String
    ) {
        self.dataType = dataType
        self.documentCount = documentCount
        self.extraData = extraData
        self.id = id
        self.name = name
    }
}

public extension CustomField {

    private enum CodingKeys: String, CodingKey {
        case dataType, documentCount, extraData, id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataType = try container.decode(CustomFieldDataType.self, forKey: .dataType)
        documentCount = try container.decodeIfPresent(Int.self, forKey: .documentCount) ?? 0
        extraData = try container.decodeIfPresent(CustomFieldExtraData.self, forKey: .extraData)
        id = try container.decode(Id.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dataType, forKey: .dataType)
        try container.encode(documentCount, forKey: .documentCount)
        try container.encodeIfPresent(extraData, forKey: .extraData)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

public extension CustomField {

    static func testValue(
        dataType: CustomFieldDataType = .string,
        documentCount: Int = 0,
        extraData: CustomFieldExtraData? = nil,
        id: Id = 1,
        name: String = "Test CustomField"
    ) -> Self {
        .init(
            dataType: dataType,
            documentCount: documentCount,
            extraData: extraData,
            id: id,
            name: name
        )
    }
}

public extension Array where Element == CustomField {

    static var previewValue: Self {
        [
            .testValue(dataType: .string, documentCount: 3, id: 1, name: "Reference"),
            .testValue(dataType: .date, documentCount: 6, id: 2, name: "Due date"),
            .testValue(dataType: .boolean, documentCount: 9, id: 3, name: "Paid"),
            .testValue(
                dataType: .monetary,
                documentCount: 12,
                extraData: .init(defaultCurrency: "EUR"),
                id: 4,
                name: "Invoice total"
            ),
            .testValue(
                dataType: .select,
                documentCount: 15,
                extraData: .init(selectOptions: [
                    .init(id: "aqgT3m4XZw8aw3Ou", label: "Open"),
                    .init(id: "MOddUdj2nhfCEsqp", label: "Closed")
                ]),
                id: 5,
                name: "Status"
            )
        ]
    }
}

extension CustomField: Comparable {
    public static func < (lhs: CustomField, rhs: CustomField) -> Bool {
        lhs.name < rhs.name
    }
}

extension CustomField: CustomStringConvertible {
    public var description: String {
        name
    }
}

public extension CustomField.Id {

    func get(_ server: Server) -> CustomField? {
        @Dependency(\.apiCache)
        var apiCache

        return apiCache.customField(id: self, server: server)
    }
}
