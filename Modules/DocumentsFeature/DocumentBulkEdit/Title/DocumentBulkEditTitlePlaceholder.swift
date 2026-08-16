import Foundation

public enum DocumentBulkEditTitlePlaceholder: String, CaseIterable, Identifiable {
    case added = "{added}"
    case addedDay = "{added_day}"
    case addedMonth = "{added_month}"
    case addedMonthName = "{added_month_name}"
    case addedMonthNameShort = "{added_month_name_short}"
    case addedYear = "{added_year}"
    case addedYearShort = "{added_year_short}"
    case asn = "{asn}"
    case correspondent = "{correspondent}"
    case created = "{created}"
    case createdDay = "{created_day}"
    case createdMonth = "{created_month}"
    case createdMonthName = "{created_month_name}"
    case createdMonthNameShort = "{created_month_name_short}"
    case createdYear = "{created_year}"
    case createdYearShort = "{created_year_short}"
    case docPk = "{doc_pk}"
    case documentType = "{document_type}"
    case originalName = "{original_name}"
    case ownerUsername = "{owner_username}"
    case tagList = "{tag_list}"
    case title = "{title}"

    public var id: String { rawValue }

    var localized: LocalizedStringResource {
        switch self {
        case .added:
            .bulkEditTitlePlaceholderAdded
        case .addedDay:
            .bulkEditTitlePlaceholderAddedDay
        case .addedMonth:
            .bulkEditTitlePlaceholderAddedMonth
        case .addedMonthName:
            .bulkEditTitlePlaceholderAddedMonthName
        case .addedMonthNameShort:
            .bulkEditTitlePlaceholderAddedMonthNameShort
        case .addedYear:
            .bulkEditTitlePlaceholderAddedYear
        case .addedYearShort:
            .bulkEditTitlePlaceholderAddedYearShort
        case .asn:
            .bulkEditTitlePlaceholderAsn
        case .correspondent:
            .bulkEditTitlePlaceholderCorrespondent
        case .created:
            .bulkEditTitlePlaceholderCreated
        case .createdDay:
            .bulkEditTitlePlaceholderCreatedDay
        case .createdMonth:
            .bulkEditTitlePlaceholderCreatedMonth
        case .createdMonthName:
            .bulkEditTitlePlaceholderCreatedMonthName
        case .createdMonthNameShort:
            .bulkEditTitlePlaceholderCreatedMonthNameShort
        case .createdYear:
            .bulkEditTitlePlaceholderCreatedYear
        case .createdYearShort:
            .bulkEditTitlePlaceholderCreatedYearShort
        case .docPk:
            .bulkEditTitlePlaceholderDocPk
        case .documentType:
            .bulkEditTitlePlaceholderDocumentType
        case .originalName:
            .bulkEditTitlePlaceholderOriginalName
        case .ownerUsername:
            .bulkEditTitlePlaceholderOwnerUsername
        case .tagList:
            .bulkEditTitlePlaceholderTagList
        case .title:
            .bulkEditTitlePlaceholderTitle
        }
    }
}
