public enum FilterRuleType: Int, CaseIterable, Codable, Equatable, Identifiable, Hashable, Sendable {
    case title = 0
    case simpleTitle = 48
    case content = 1
    case asn = 2
    case asnIsNull = 18
    case asnGreaterThan = 23
    case asnLowerThan = 24
    case correspondent = 3
    case hasCorrespondentAny = 26
    case doesNotHaveCorrespondent = 27
    case documentType = 4
    case hasDocumentTypeAny = 28
    case doesNotHaveDocumentType = 29
    case isInInbox = 5
    case hasTagsAll = 6
    case hasAnyTag = 7
    case doesNotHaveTag = 17
    case hasTagsAny = 22
    case storagePath = 25
    case hasStoragePathAny = 30
    case doesNotHaveStoragePath = 31
    case createdBefore = 8
    case createdAfter = 9
    case createdYear = 10
    case createdMonth = 11
    case createdDay = 12
    case addedBefore = 13
    case addedAfter = 14
    case createdTo = 43
    case createdFrom = 44
    case addedTo = 45
    case addedFrom = 46
    case modifiedBefore = 15
    case modifiedAfter = 16
    case titleContent = 19
    case simpleText = 49
    case fulltextQuery = 20
    case fulltextMoreLike = 21
    case owner = 32
    case ownerAny = 33
    case ownerIsNull = 34
    case ownerDoesNotInclude = 35
    case sharedByUser = 37
    case customFieldsText = 36
    case hasCustomFieldsAll = 38
    case hasCustomFieldsAny = 39
    case doesNotHaveCustomFields = 40
    case hasAnyCustomFields = 41
    case customFieldsQuery = 42
    case mimeType = 47

    public var id: Int {
        rawValue
    }

    public var shouldMergeValues: Bool {
        switch self {
        case .fulltextQuery:
            return true
        default:
            return false
        }
    }
}

extension FilterRuleType {

    var isNullQueryItemName: String? {
        switch self {
        case .correspondent:
            return "correspondent__isnull"
        case .documentType:
            return "document_type__isnull"
        case .storagePath:
            return "storage_path__isnull"
        default:
            return nil
        }
    }

    var queryItemName: String {
        switch self {
        case .title:
            return "title__icontains"
        case .simpleTitle:
            return "title_search"
        case .content:
            return "content__icontains"
        case .asn:
            return "archive_serial_number"
        case .asnIsNull:
            return "archive_serial_number__isnull"
        case .asnGreaterThan:
            return "archive_serial_number__gt"
        case .asnLowerThan:
            return "archive_serial_number__lt"
        case .correspondent:
            return "correspondent__id"
        case .hasCorrespondentAny:
            return "correspondent__id__in"
        case .doesNotHaveCorrespondent:
            return "correspondent__id__none"
        case .documentType:
            return "document_type__id"
        case .hasDocumentTypeAny:
            return "document_type__id__in"
        case .doesNotHaveDocumentType:
            return "document_type__id__none"
        case .isInInbox:
            return "is_in_inbox"
        case .hasTagsAll:
            return "tags__id__all"
        case .hasAnyTag:
            return "is_tagged"
        case .doesNotHaveTag:
            return "tags__id__none"
        case .hasTagsAny:
            return "tags__id__in"
        case .storagePath:
            return "storage_path__id"
        case .hasStoragePathAny:
            return "storage_path__id__in"
        case .doesNotHaveStoragePath:
            return "storage_path__id__none"
        case .createdBefore:
            return "created__date__lt"
        case .createdAfter:
            return "created__date__gt"
        case .createdYear:
            return "created__year"
        case .createdMonth:
            return "created__month"
        case .createdDay:
            return "created__day"
        case .addedBefore:
            return "added__date__lt"
        case .addedAfter:
            return "added__date__gt"
        case .createdTo:
            return "created__date__lte"
        case .createdFrom:
            return "created__date__gte"
        case .addedTo:
            return "added__date__lte"
        case .addedFrom:
            return "added__date__gte"
        case .modifiedBefore:
            return "modified__date__lt"
        case .modifiedAfter:
            return "modified__date__gt"
        case .titleContent:
            return "title_content"
        case .simpleText:
            return "text"
        case .fulltextQuery:
            return "query"
        case .fulltextMoreLike:
            return "more_like_id"
        case .owner:
            return "owner__id"
        case .ownerAny:
            return "owner__id__in"
        case .ownerIsNull:
            return "owner__isnull"
        case .ownerDoesNotInclude:
            return "owner__id__none"
        case .sharedByUser:
            return "shared_by__id"
        case .customFieldsText:
            return "custom_fields__icontains"
        case .hasCustomFieldsAll:
            return "custom_fields__id__all"
        case .hasCustomFieldsAny:
            return "custom_fields__id__in"
        case .doesNotHaveCustomFields:
            return "custom_fields__id__none"
        case .hasAnyCustomFields:
            return "has_custom_fields"
        case .customFieldsQuery:
            return "custom_field_query"
        case .mimeType:
            return "mime_type"
        }
    }
}
