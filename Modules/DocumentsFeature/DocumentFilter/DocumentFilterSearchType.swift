import Foundation

public enum DocumentFilterSearchType: String, CaseIterable, Equatable, Identifiable, Sendable {
    case advanced
    case asn
    case customFields
    case title
    case titleContent

    public var id: RawValue { rawValue }
}

extension DocumentFilterSearchType {

    var localized: LocalizedStringResource {
        switch self {
        case .advanced:
            .searchTypeAdvanced
        case .asn:
            .searchTypeAsn
        case .customFields:
            .searchTypeCustomFields
        case .title:
            .searchTypeTitle
        case .titleContent:
            .searchTypeTitleContent
        }
    }
}
