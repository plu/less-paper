import ApiInterface
import Components
import Dependencies
import DesignTokens
import IdentifiedCollections
import SwiftUI

struct DocumentFormCustomFieldRow: View {

    var body: some View {
        HStack(alignment: .center, spacing: .x2) {
            editor()

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.m3Outline)
                    .accessibilityLabel(.removeCustomField)
            }
            .buttonStyle(.borderless)
        }
    }

    let field: CustomField

    let linkedDocuments: IdentifiedArrayOf<Document>

    let onDocumentLinkTapped: () -> Void

    let onRemove: () -> Void

    @Binding
    var value: DocumentFormCustomFieldValue

    @Dependency(\.date.now)
    private var now

    private var title: LocalizedStringResource {
        .init(stringLiteral: field.name)
    }

    @ViewBuilder
    private func editor() -> some View {
        switch field.dataType {
        case .boolean:
            booleanEditor()
        case .date:
            dateEditor()
        case .float, .integer:
            numberEditor()
        case .longText:
            longTextEditor()
        case .string, .url:
            textEditor()
        case .documentLink:
            documentLinkEditor()
        case .monetary:
            monetaryEditor()
        case .select:
            selectEditor()
        case .unknown:
            readOnlyEditor()
        }
    }

    @ViewBuilder
    private func monetaryEditor() -> some View {
        Field(title, padding: .x3) {
            HStack(spacing: .x2) {
                Picker("", selection: currencyBinding()) {
                    ForEach(currencyOptions, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .accessibilityLabel(.currency)
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(.m3OnSurface)

                TextField(field.name, text: amountBinding())
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
            }
        }
        .error(errorText)
    }

    @ViewBuilder
    private func selectEditor() -> some View {
        Field(title) {
            HStack {
                Picker("", selection: selectBinding()) {
                    Text(verbatim: "—").tag(String?.none)
                    ForEach(field.extraData?.selectOptions ?? [], id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(.m3OnSurface)
                .offset(x: -12)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func documentLinkEditor() -> some View {
        Field(title) {
            HStack(spacing: .x3) {
                if linkedIds.isEmpty {
                    Text(verbatim: "—")
                        .foregroundColor(.m3Outline)
                    Spacer()
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: .x3) {
                            ForEach(linkedIds, id: \.self) { id in
                                Text(linkedDocuments[id: id]?.title ?? "#\(id.rawValue)")
                                    .capsule()
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .contentShape(.capsule)
        .onTapGesture(perform: onDocumentLinkTapped)
    }

    @ViewBuilder
    private func booleanEditor() -> some View {
        Field(title) {
            HStack {
                Toggle(isOn: Binding(
                    get: {
                        guard case let .boolean(flag) = value else {
                            return false
                        }
                        return flag
                    },
                    set: { value = .boolean($0) }
                )) {
                    Text(title)
                }
                .labelsHidden()

                Spacer()
            }
        }
        .tint(Color.m3Primary)
    }

    // DateField binds a non-optional Date, so an unset field would render as today and read as a
    // date the user chose. The placeholder keeps "no date" visible until they pick one.
    @ViewBuilder
    private func dateEditor() -> some View {
        if case let .date(date) = value, let date {
            DateField(
                title: title,
                value: Binding(
                    get: { date },
                    set: { value = .date($0) }
                ),
                suggestions: .constant([])
            )
        } else {
            Field(title) {
                HStack {
                    Text(.setDate)
                        .foregroundColor(.m3Outline)
                    Spacer()
                }
            }
            .contentShape(.capsule)
            .onTapGesture {
                value = .date(now)
            }
        }
    }

    @ViewBuilder
    private func numberEditor() -> some View {
        Field(title) {
            TextField(field.name, text: textBinding())
                .keyboardType(field.dataType == .integer ? .numberPad : .decimalPad)
                .textFieldStyle(.plain)
        }
        .error(errorText)
    }

    @ViewBuilder
    private func textEditor() -> some View {
        Field(title) {
            TextField(field.name, text: textBinding())
                .autocorrectionDisabled(field.dataType == .url)
                .keyboardType(field.dataType == .url ? .URL : .default)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(field.dataType == .url ? .never : .sentences)
        }
    }

    @ViewBuilder
    private func longTextEditor() -> some View {
        Field(title, padding: .x3) {
            TextEditor(text: textBinding())
                .frame(minHeight: 88)
                .font(.body)
                .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func readOnlyEditor() -> some View {
        Field(title) {
            HStack {
                Text(verbatim: "—")
                    .foregroundColor(.m3Outline)
                Spacer()
            }
        }
        .readOnly()
    }

    private var errorText: String? {
        value.validationError.map { String(localized: $0) }
    }

    private var linkedIds: [Document.Id] {
        guard case let .documentLink(ids) = value else {
            return []
        }
        return ids
    }

    // A code the server already holds may not be in the common list. Prepending it keeps the
    // picker's selection matched — an unmatched tag renders as a blank menu label.
    private var currencyOptions: [String] {
        guard case let .monetary(currency, _) = value,
              !currency.isEmpty,
              !Locale.commonISOCurrencyCodes.contains(currency)
        else {
            return Locale.commonISOCurrencyCodes
        }
        return [currency] + Locale.commonISOCurrencyCodes
    }

    private func amountBinding() -> Binding<String> {
        Binding(
            get: {
                guard case let .monetary(_, amount) = value else {
                    return ""
                }
                return amount
            },
            set: { amount in
                guard case let .monetary(currency, _) = value else {
                    return
                }
                value = .monetary(currency: currency, amount: amount)
            }
        )
    }

    private func currencyBinding() -> Binding<String> {
        Binding(
            get: {
                guard case let .monetary(currency, _) = value else {
                    return ""
                }
                return currency
            },
            set: { currency in
                guard case let .monetary(_, amount) = value else {
                    return
                }
                value = .monetary(currency: currency, amount: amount)
            }
        )
    }

    private func selectBinding() -> Binding<String?> {
        Binding(
            get: {
                guard case let .select(id) = value else {
                    return nil
                }
                return id
            },
            set: { value = .select($0) }
        )
    }

    private func textBinding() -> Binding<String> {
        Binding(
            get: {
                switch value {
                case let .number(text):
                    text
                case let .text(text):
                    text
                default:
                    ""
                }
            },
            set: { text in
                switch value {
                case .number:
                    value = .number(text)
                default:
                    value = .text(text)
                }
            }
        )
    }
}
