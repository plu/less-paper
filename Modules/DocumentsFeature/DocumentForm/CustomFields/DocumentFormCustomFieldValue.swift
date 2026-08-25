import ApiInterface
import Foundation

enum DocumentFormCustomFieldValue: Equatable, Sendable {
    case boolean(Bool)
    case date(Date?)
    case documentLink([Document.Id])
    case monetary(currency: String, amount: String)
    case number(String)
    case select(String?)
    case text(String)
    // A data type this app does not know. Held verbatim and rendered read-only: a save replaces the
    // document's whole list, so anything dropped here is deleted on the server.
    case unsupported(JSONValue)
}

extension DocumentFormCustomFieldValue {

    init(field: CustomField, json: JSONValue) {
        switch field.dataType {
        case .boolean:
            self = .boolean(json == .bool(true))
        case .date:
            self = .date(json.stringValue.flatMap(DateFormatter.customFieldDate.date(from:)))
        case .documentLink:
            self = .documentLink((json.arrayValue ?? []).compactMap { value in
                value.intValue.map { Document.Id(rawValue: $0) }
            })
        case .float, .integer:
            self = .number(Self.text(from: json, isInteger: field.dataType == .integer))
        case .monetary:
            self = Self.monetary(from: json.stringValue ?? "", field: field)
        case .select:
            self = .select(json.stringValue)
        case .longText, .string, .url:
            self = .text(json.stringValue ?? "")
        case .unknown:
            self = .unsupported(json)
        }
    }

    static func empty(field: CustomField) -> Self {
        switch field.dataType {
        // A Toggle has no third position, so an attached boolean starts at a definite No.
        case .boolean:
            .boolean(false)
        case .date:
            .date(nil)
        case .documentLink:
            .documentLink([])
        case .float, .integer:
            .number("")
        case .monetary:
            .monetary(currency: Self.defaultCurrency(field: field), amount: "")
        case .select:
            .select(nil)
        case .longText, .string, .url:
            .text("")
        case .unknown:
            .unsupported(.null)
        }
    }

    func json(field: CustomField) -> JSONValue {
        switch self {
        case let .boolean(flag):
            .bool(flag)
        case let .date(date):
            date.map { .string(DateFormatter.customFieldDate.string(from: $0)) } ?? .null
        case let .documentLink(ids):
            ids.isEmpty ? .null : .array(ids.map { .number(Double($0.rawValue)) })
        case let .monetary(currency, amount):
            Self.normalisedAmount(amount).map { .string("\(currency)\($0)") } ?? .null
        case let .number(text):
            Double(text).map { .number($0) } ?? .null
        case let .select(id):
            id.map { .string($0) } ?? .null
        case let .text(text):
            text.isEmpty ? .null : .string(text)
        case let .unsupported(json):
            json
        }
    }

    var isEditable: Bool {
        guard case .unsupported = self else {
            return true
        }
        return false
    }

    var validationError: LocalizedStringResource? {
        switch self {
        case let .monetary(_, amount):
            amount.isEmpty || Self.normalisedAmount(amount) != nil ? nil : .invalidNumber
        case let .number(text):
            text.isEmpty || Self.amountParts(text) != nil ? nil : .invalidNumber
        case .boolean, .date, .documentLink, .select, .text, .unsupported:
            nil
        }
    }
}

private extension DocumentFormCustomFieldValue {

    static func defaultCurrency(field: CustomField) -> String {
        field.extraData?.defaultCurrency
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }

    static func monetary(from raw: String, field: CustomField) -> Self {
        let code = String(raw.prefix(3))
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isUppercase }) else {
            return .monetary(currency: defaultCurrency(field: field), amount: raw)
        }
        return .monetary(currency: code, amount: String(raw.dropFirst(3)))
    }

    // A Double that is whole has to render without its ".0": the server types the field as an
    // integer and rejects 7.0 for it.
    static func text(from json: JSONValue, isInteger: Bool) -> String {
        guard case let .number(number) = json else {
            return ""
        }
        return isInteger || number.rounded() == number ? String(Int(number)) : String(number)
    }

    static func amountParts(_ amount: String) -> (whole: String, fraction: String)? {
        let parts = amount.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else {
            return nil
        }

        var whole = String(parts[0])
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        let isNegative = whole.hasPrefix("-")
        if isNegative {
            whole.removeFirst()
        }

        guard !whole.isEmpty,
              whole.allSatisfy({ $0.isASCII && $0.isNumber }),
              fraction.count <= 2,
              fraction.allSatisfy({ $0.isASCII && $0.isNumber })
        else {
            return nil
        }

        return (isNegative ? "-\(whole)" : whole, fraction)
    }

    // Verified against the server: a currency code obliges the decimal point, so "EUR1234" is a 400
    // where the bare "1234" is fine. Every amount this app sends carries a code.
    static func normalisedAmount(_ amount: String) -> String? {
        guard let parts = amountParts(amount) else {
            return nil
        }
        return "\(parts.whole).\(parts.fraction.padding(toLength: 2, withPad: "0", startingAt: 0))"
    }
}

private extension DateFormatter {

    static let customFieldDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        return formatter
    }()
}

extension DocumentFormCustomFieldValue {

    // nil means "render nothing": either the value is empty, so DocumentMetadataGroupView drops the
    // row, or it is a document link, which is a row of capsules rather than a string.
    func displayValue(field: CustomField) -> String? {
        switch self {
        case let .boolean(flag):
            String(localized: flag ? .yes : .no)
        case let .date(date):
            date.map { DateFormatter.customFieldDisplay.string(from: $0) }
        case .documentLink:
            nil
        case let .monetary(currency, amount):
            amount.isEmpty ? nil : "\(currency) \(amount)"
        case let .number(text):
            text.isEmpty ? nil : text
        case let .select(id):
            id.map { optionLabel(for: $0, field: field) }
        case let .text(text):
            text.isEmpty ? nil : text
        case let .unsupported(json):
            json == .null ? nil : String(describing: json)
        }
    }

    private func optionLabel(for id: String, field: CustomField) -> String {
        field.extraData?.selectOptions?.first { $0.id == id }?.label ?? id
    }
}

private extension DateFormatter {

    static let customFieldDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
