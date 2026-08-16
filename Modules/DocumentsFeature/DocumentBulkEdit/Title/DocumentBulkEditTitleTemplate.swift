import ApiInterface
import Dependencies
import Foundation

struct DocumentBulkEditTitleTemplate: Equatable, Sendable {

    let text: String

    // Scans once and substitutes each token in place. Chaining `replacingOccurrences` per
    // placeholder instead would let a document whose own title contains `{created_year}` have it
    // expanded by the passes that follow.
    func title(for document: Document, server: Server) -> String {
        var result = ""
        var remainder = Substring(text)

        while let open = remainder.firstIndex(of: "{") {
            result += remainder[remainder.startIndex ..< open]
            remainder = remainder[open...]

            guard let close = remainder.firstIndex(of: "}"),
                  let placeholder = DocumentBulkEditTitlePlaceholder(
                      rawValue: String(remainder[remainder.startIndex ... close])
                  )
            else {
                result.append("{")
                remainder = remainder.dropFirst()
                continue
            }

            result += value(of: placeholder, for: document, server: server)
            remainder = remainder[remainder.index(after: close)...]
        }

        return result + remainder
    }

    // MARK: - Private

    private func component(_ component: Calendar.Component, of date: Date) -> String {
        @Dependency(\.calendar)
        var calendar

        return String(format: "%02d", calendar.component(component, from: date))
    }

    private func monthName(of date: Date, isShort: Bool) -> String {
        @Dependency(\.calendar)
        var calendar

        @Dependency(\.locale)
        var locale

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        let symbols = isShort ? formatter.shortMonthSymbols : formatter.monthSymbols

        return symbols?[calendar.component(.month, from: date) - 1] ?? ""
    }

    private func value(
        of placeholder: DocumentBulkEditTitlePlaceholder,
        for document: Document,
        server: Server
    ) -> String {
        switch placeholder {
        case .added:
            return document.added.ISO8601Format()
        case .addedDay:
            return component(.day, of: document.added)
        case .addedMonth:
            return component(.month, of: document.added)
        case .addedMonthName:
            return monthName(of: document.added, isShort: false)
        case .addedMonthNameShort:
            return monthName(of: document.added, isShort: true)
        case .addedYear:
            return year(of: document.added)
        case .addedYearShort:
            return String(year(of: document.added).suffix(2))
        case .asn:
            return document.archiveSerialNumber.map(String.init) ?? ""
        case .correspondent:
            return document.correspondent?.get(server)?.name ?? ""
        case .created:
            return document.created.ISO8601Format()
        case .createdDay:
            return component(.day, of: document.created)
        case .createdMonth:
            return component(.month, of: document.created)
        case .createdMonthName:
            return monthName(of: document.created, isShort: false)
        case .createdMonthNameShort:
            return monthName(of: document.created, isShort: true)
        case .createdYear:
            return year(of: document.created)
        case .createdYearShort:
            return String(year(of: document.created).suffix(2))
        case .docPk:
            return String(document.id.rawValue)
        case .documentType:
            return document.documentType?.get(server)?.name ?? ""
        case .originalName:
            guard let originalFileName = document.originalFileName else {
                return ""
            }
            return (originalFileName as NSString).deletingPathExtension
        case .ownerUsername:
            return document.owner?.get(server)?.username ?? ""
        case .tagList:
            return document.tags.compactMap { $0.get(server)?.name }.joined(separator: ",")
        case .title:
            return document.title
        }
    }

    private func year(of date: Date) -> String {
        @Dependency(\.calendar)
        var calendar

        return String(calendar.component(.year, from: date))
    }
}
