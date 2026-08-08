import Foundation

public enum SortField: String, CaseIterable, Codable, Sendable {
    case added
    case asn = "archive_serial_number"
    case correspondent = "correspondent__name"
    case created
    case documentType = "document_type__name"
    case modified
    case notes = "num_notes"
    case owner
    case title
}

public extension SortField {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try Self(rawValue: container.decode(String.self)) ?? .created
    }
}
