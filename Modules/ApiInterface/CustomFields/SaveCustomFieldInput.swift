import Foundation
import Tagged

public struct SaveCustomFieldInput: Codable, Equatable, Sendable {

    public var dataType: CustomFieldDataType?

    public var extraData: CustomFieldExtraData?

    public var name: String

    public init(
        dataType: CustomFieldDataType? = nil,
        extraData: CustomFieldExtraData? = nil,
        name: String
    ) {
        self.dataType = dataType
        self.extraData = extraData
        self.name = name
    }
}

public extension SaveCustomFieldInput {

    init(customField: CustomField?) {
        guard let customField else {
            self.init(
                dataType: .string,
                extraData: nil,
                name: ""
            )
            return
        }
        self.init(
            dataType: customField.dataType == .unknown ? nil : customField.dataType,
            extraData: customField.extraData,
            name: customField.name
        )
    }
}

public extension SaveCustomFieldInput {

    static func testValue(
        dataType: CustomFieldDataType? = .string,
        extraData: CustomFieldExtraData? = nil,
        name: String = "Test CustomField"
    ) -> Self {
        .init(
            dataType: dataType,
            extraData: extraData,
            name: name
        )
    }
}
