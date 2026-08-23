import ApiInterface
import Components
import ComposableArchitecture
import Foundation

public struct CustomFieldFormInput: Equatable, Sendable {

    var dataType: CustomFieldDataType = .string

    var defaultCurrency = FieldState(value: "")

    var focusedOptionId: UUID?

    var name = FieldState(focused: true, value: "")

    var selectOptions: IdentifiedArrayOf<CustomFieldSelectOptionInput> = []
}

extension CustomFieldFormInput {

    init(customField: CustomField?) {
        guard let customField else {
            self.init()
            return
        }
        self.init(
            dataType: customField.dataType,
            defaultCurrency: .init(value: customField.extraData?.defaultCurrency ?? ""),
            focusedOptionId: nil,
            name: .init(value: customField.name),
            selectOptions: IdentifiedArray(
                uniqueElements: (customField.extraData?.selectOptions ?? []).map {
                    CustomFieldSelectOptionInput(
                        id: UUID(),
                        label: $0.label,
                        serverId: $0.id
                    )
                }
            )
        )
    }

    var apiValue: SaveCustomFieldInput {
        .init(
            dataType: dataType == .unknown ? nil : dataType,
            extraData: extraDataApiValue,
            name: name.value
        )
    }

    mutating func applyFieldErrors(from apiError: ApiError) {
        for (fieldName, keyPath) in CustomFieldFormField.fieldStateKeyPaths {
            if let error = apiError.errorForField(fieldName.rawValue) {
                self[keyPath: keyPath] = error
            }
        }
    }

    private var extraDataApiValue: CustomFieldExtraData? {
        switch dataType {
        case .monetary:
            guard !defaultCurrency.value.isEmpty else {
                return nil
            }
            return .init(defaultCurrency: defaultCurrency.value)
        case .select:
            // An option the user added but left blank is dropped rather than sent: the server would
            // store an unlabelled choice that can never be picked meaningfully.
            let options = selectOptions
                .filter { !$0.label.isEmpty }
                .map(\.apiValue)
            return options.isEmpty ? nil : .init(selectOptions: options)
        case .boolean, .date, .documentLink, .float, .integer, .longText, .string, .unknown, .url:
            return nil
        }
    }
}
