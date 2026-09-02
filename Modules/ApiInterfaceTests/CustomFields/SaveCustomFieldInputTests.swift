@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveCustomFieldInputTests {

    @Test
    func encode_plainType_omitsExtraData() async throws {
        let input = SaveCustomFieldInput(dataType: .string, name: "Reference")

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "data_type" : "string",
          "name" : "Reference"
        }
        """)
    }

    @Test
    func encode_select_includesOptions() async throws {
        let input = SaveCustomFieldInput(
            dataType: .select,
            extraData: .init(selectOptions: [.init(label: "Open")]),
            name: "Status"
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "data_type" : "select",
          "extra_data" : {
            "select_options" : [
              {
                "label" : "Open"
              }
            ]
          },
          "name" : "Status"
        }
        """)
    }

    @Test
    func encode_monetary_includesDefaultCurrency() async throws {
        let input = SaveCustomFieldInput(
            dataType: .monetary,
            extraData: .init(defaultCurrency: "EUR"),
            name: "Invoice total"
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "data_type" : "monetary",
          "extra_data" : {
            "default_currency" : "EUR"
          },
          "name" : "Invoice total"
        }
        """)
    }

    // An unknown data type must never be written back — the server would reject "unknown", and the
    // app has no business changing a type it does not understand.
    @Test
    func init_customField_unknownDataType_omitsDataType() async throws {
        let input = SaveCustomFieldInput(customField: .testValue(dataType: .unknown, name: "Future"))

        #expect(input.dataType == nil)
        #expect(input.name == "Future")

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "name" : "Future"
        }
        """)
    }

    @Test
    func init_customField_nil_defaultsToString() async throws {
        let input = SaveCustomFieldInput(customField: nil)

        #expect(input.dataType == .string)
        #expect(input.extraData == nil)
        #expect(input.name == "")
    }
}
