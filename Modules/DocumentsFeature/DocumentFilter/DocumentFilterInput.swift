import ApiInterface
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import IdentifiedCollections
import SavedViewsFeature
import StoragePathsFeature
import SwiftSharing
import TagsFeature

public struct DocumentFilterInput: Equatable {
    struct ListFilter<T: Equatable & Hashable>: Equatable {
        var rule = DocumentFilterGenericValueRule.include
        var selection = Set<T>()
    }

    public struct DateFilter: Equatable {
        public struct Bound: Equatable {
            var date: Date?
            var ruleType: FilterRuleType?
        }

        var from = Bound()
        var to = Bound()
        var type = DocumentFilterDateType.created

        func ruleType(for bound: Bound, isLowerBound: Bool) -> FilterRuleType {
            if let ruleType = bound.ruleType, ruleType.dateType == type {
                return ruleType
            }
            return isLowerBound ? type.fromRuleType : type.toRuleType
        }
    }

    struct SortFilter: Equatable {
        var direction = SortDirection.descending
        var field = SortField.added
    }

    struct TagFilter: Equatable {
        var rule = DocumentFilterTagRule.all
        var selection = DocumentFilterTagSelection()
    }

    var asnType = DocumentFilterASNType.equals
    var correspondent = ListFilter<Correspondent>()
    var date = DateFilter()
    var documentType = ListFilter<DocumentType>()
    var searchType = DocumentFilterSearchType.titleContent
    var searchValue = ""
    var sort = SortFilter()
    var storagePath = ListFilter<StoragePath>()
    var tag = TagFilter()
    var unsupportedFilterRules = [FilterRule]()
}

extension DocumentFilterInput.TagFilter {
    static func == (lhs: DocumentFilterInput.TagFilter, rhs: DocumentFilterInput.TagFilter) -> Bool {
        guard lhs.rule == rhs.rule else {
            return false
        }
        switch lhs.rule {
        case .all:
            return lhs.selection.all == rhs.selection.all
        case .any:
            return lhs.selection.any == rhs.selection.any
        case .assigned, .notAssigned:
            return true
        }
    }
}

extension DocumentFilterInput {

    init(
        filterRules: [FilterRule]?,
        server: Server,
        sortDirection: SortDirection?,
        sortField: SortField?
    ) {
        @Shared(.correspondents(server))
        var correspondents

        @Shared(.documentTypes(server))
        var documentTypes

        @Shared(.storagePaths(server))
        var storagePaths

        @Shared(.tags(server))
        var tags

        correspondent.selection = []
        date = .init()
        documentType.selection = []
        sort.direction = sortDirection ?? .descending
        sort.field = sortField ?? .added
        storagePath.selection = []
        tag.selection = .init()
        unsupportedFilterRules = []

        var dateRules = [FilterRule]()

        for filterRule in filterRules ?? [] {
            if filterRule.ruleType.dateType != nil {
                dateRules.append(filterRule)
                continue
            }

            switch filterRule.ruleType {
            case .asn:
                asnType = .equals
                searchType = .asn
                setSearchValue(filterRule)
            case .asnIsNull:
                asnType = filterRule.value.boolValue ? .isEmpty : .isNotEmpty
                searchType = .asn
            case .asnGreaterThan:
                asnType = .greaterThan
                searchType = .asn
                setSearchValue(filterRule)
            case .asnLowerThan:
                asnType = .lowerThan
                searchType = .asn
                setSearchValue(filterRule)
            case .customFieldsText:
                searchType = .customFields
                setSearchValue(filterRule)
            case .correspondent:
                correspondent.rule = .notAssigned
            case .documentType:
                documentType.rule = .notAssigned
            case .doesNotHaveCorrespondent:
                correspondent.rule = .exclude
                correspondent.selection = correspondent.selection.union(
                    resolve(filterRule, in: correspondents)
                )
            case .doesNotHaveDocumentType:
                documentType.rule = .exclude
                documentType.selection = documentType.selection.union(
                    resolve(filterRule, in: documentTypes)
                )
            case .doesNotHaveStoragePath:
                storagePath.rule = .exclude
                storagePath.selection = storagePath.selection.union(
                    resolve(filterRule, in: storagePaths)
                )
            case .doesNotHaveTag:
                tag.rule = .all
                tag.selection.all.exclude = tag.selection.all.exclude.union(
                    resolve(filterRule, in: tags)
                )
            case .fulltextQuery:
                searchType = .advanced
                setSearchValue(filterRule)
            case .hasAnyTag:
                // `is_tagged=1` means "has at least one tag"; only `0` means "not tagged".
                tag.rule = filterRule.value == "0" ? .notAssigned : .assigned
            case .hasCorrespondentAny:
                correspondent.rule = .include
                correspondent.selection = correspondent.selection.union(
                    resolve(filterRule, in: correspondents)
                )
            case .hasDocumentTypeAny:
                documentType.rule = .include
                documentType.selection = documentType.selection.union(
                    resolve(filterRule, in: documentTypes)
                )
            case .hasStoragePathAny:
                storagePath.rule = .include
                storagePath.selection = storagePath.selection.union(
                    resolve(filterRule, in: storagePaths)
                )
            case .hasTagsAll:
                tag.rule = .all
                tag.selection.all.include = tag.selection.all.include.union(
                    resolve(filterRule, in: tags)
                )
            case .hasTagsAny:
                tag.rule = .any
                tag.selection.any = tag.selection.any.union(
                    resolve(filterRule, in: tags)
                )
            case .storagePath:
                storagePath.rule = .notAssigned
            case .title:
                searchType = .title
                setSearchValue(filterRule)
            case .titleContent:
                searchType = .titleContent
                setSearchValue(filterRule)
            default:
                unsupportedFilterRules.append(filterRule)
            }
        }

        apply(dateRules)
    }

    private mutating func apply(_ dateRules: [FilterRule]) {
        guard !dateRules.isEmpty else {
            return
        }

        date.type = dateRules.contains { $0.ruleType.dateType == .created } ? .created : .added

        for filterRule in dateRules {
            guard filterRule.ruleType.dateType == date.type,
                  let value = filterRule.value,
                  let parsed = DateFormatter.filterRule.date(from: value)
            else {
                unsupportedFilterRules.append(filterRule)
                continue
            }

            let bound = DateFilter.Bound(date: parsed, ruleType: filterRule.ruleType)
            if filterRule.ruleType.isDateLowerBound {
                date.from = bound
            } else {
                date.to = bound
            }
        }
    }

    var filterRules: [FilterRule] {
        var filterRules = [FilterRule]()

        switch searchType {
        case .advanced:
            append(&filterRules, ruleType: .fulltextQuery)
        case .asn:
            switch asnType {
            case .equals:
                filterRules.append(.init(ruleType: .asn, value: searchValue))
            case .isEmpty:
                filterRules.append(.init(ruleType: .asnIsNull, value: true.stringValue))
            case .isNotEmpty:
                filterRules.append(.init(ruleType: .asnIsNull, value: false.stringValue))
            case .greaterThan:
                filterRules.append(.init(ruleType: .asnGreaterThan, value: searchValue))
            case .lowerThan:
                filterRules.append(.init(ruleType: .asnLowerThan, value: searchValue))
            }
        case .customFields:
            append(&filterRules, ruleType: .customFieldsText)
        case .title:
            append(&filterRules, ruleType: .title)
        case .titleContent:
            append(&filterRules, ruleType: .titleContent)
        }

        switch correspondent.rule {
        case .exclude:
            if !correspondent.selection.isEmpty {
                filterRules.append(contentsOf: correspondent.selection.map {
                    .init(
                        ruleType: .doesNotHaveCorrespondent,
                        value: String($0.id)
                    )
                })
            }
        case .include:
            if !correspondent.selection.isEmpty {
                filterRules.append(contentsOf: correspondent.selection.map {
                    .init(
                        ruleType: .hasCorrespondentAny,
                        value: String($0.id)
                    )
                })
            }
        case .notAssigned:
            filterRules.append(.init(ruleType: .correspondent, value: nil))
        }

        switch documentType.rule {
        case .exclude:
            if !documentType.selection.isEmpty {
                filterRules.append(contentsOf: documentType.selection.map {
                    .init(
                        ruleType: .doesNotHaveDocumentType,
                        value: String($0.id)
                    )
                })
            }
        case .include:
            if !documentType.selection.isEmpty {
                filterRules.append(contentsOf: documentType.selection.map {
                    .init(
                        ruleType: .hasDocumentTypeAny,
                        value: String($0.id)
                    )
                })
            }
        case .notAssigned:
            filterRules.append(.init(ruleType: .documentType, value: nil))
        }

        switch storagePath.rule {
        case .exclude:
            if !storagePath.selection.isEmpty {
                filterRules.append(contentsOf: storagePath.selection.map {
                    .init(
                        ruleType: .doesNotHaveStoragePath,
                        value: String($0.id)
                    )
                })
            }
        case .include:
            if !storagePath.selection.isEmpty {
                filterRules.append(contentsOf: storagePath.selection.map {
                    .init(
                        ruleType: .hasStoragePathAny,
                        value: String($0.id)
                    )
                })
            }
        case .notAssigned:
            filterRules.append(.init(ruleType: .storagePath, value: nil))
        }

        switch tag.rule {
        case .all:
            filterRules.append(contentsOf: tag.selection.all.exclude.map {
                .init(
                    ruleType: .doesNotHaveTag,
                    value: String($0.id)
                )
            })
            filterRules.append(contentsOf: tag.selection.all.include.map {
                .init(
                    ruleType: .hasTagsAll,
                    value: String($0.id)
                )
            })
        case .any:
            filterRules.append(contentsOf: tag.selection.any.map {
                .init(
                    ruleType: .hasTagsAny,
                    value: String($0.id)
                )
            })
        case .assigned:
            filterRules.append(.init(ruleType: .hasAnyTag, value: "1"))
        case .notAssigned:
            filterRules.append(.init(ruleType: .hasAnyTag, value: "0"))
        }

        if let from = date.from.date {
            filterRules.append(.init(
                ruleType: date.ruleType(for: date.from, isLowerBound: true),
                value: DateFormatter.filterRule.string(from: from)
            ))
        }
        if let to = date.to.date {
            filterRules.append(.init(
                ruleType: date.ruleType(for: date.to, isLowerBound: false),
                value: DateFormatter.filterRule.string(from: to)
            ))
        }

        filterRules.append(contentsOf: unsupportedFilterRules)

        return filterRules
    }

    private func append(_ filterRules: inout [FilterRule], ruleType: FilterRuleType) {
        if !searchValue.isEmpty {
            filterRules.append(.init(ruleType: ruleType, value: searchValue))
        }
    }

    private mutating func setSearchValue(_ filterRule: FilterRule) {
        if let value = filterRule.value {
            searchValue = value
        }
    }

    private mutating func resolve<Value: Identifiable>(
        _ filterRule: FilterRule,
        in cache: IdentifiedArrayOf<Value>
    ) -> Set<Value> where Value: Hashable, Value.ID: RawRepresentable, Value.ID.RawValue == Int {
        var resolved = Set<Value>()

        for id in filterRule.value.ids() {
            guard let value = Value.ID(rawValue: id).flatMap({ cache[id: $0] }) else {
                unsupportedFilterRules.append(
                    .init(ruleType: filterRule.ruleType, value: String(id))
                )
                continue
            }
            resolved.insert(value)
        }

        return resolved
    }
}

extension DocumentFilterInput {

    static func testValue(
        asnType: DocumentFilterASNType = .equals,
        correspondent: ListFilter<Correspondent> = .init(),
        documentType: ListFilter<DocumentType> = .init(),
        searchType: DocumentFilterSearchType = .titleContent,
        searchValue: String = "",
        sort: SortFilter = .init(),
        storagePath: ListFilter<StoragePath> = .init(),
        tag: TagFilter = .init(),
        unsupportedFilterRules: [FilterRule] = []
    ) -> Self {
        .init(
            asnType: asnType,
            correspondent: correspondent,
            documentType: documentType,
            searchType: searchType,
            searchValue: searchValue,
            sort: sort,
            storagePath: storagePath,
            tag: tag,
            unsupportedFilterRules: unsupportedFilterRules
        )
    }
}
