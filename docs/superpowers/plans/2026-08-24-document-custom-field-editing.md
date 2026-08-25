# Editing custom fields on documents — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the document edit sheet a **Custom fields** section that attaches, edits and detaches
custom field values on one document.

**Architecture:** `Document` and `UpdateDocumentInput` gain a `[DocumentCustomField]` carrying the
raw `JSONValue` per field. The form holds a typed editor state, `DocumentFormCustomFieldValue`, that
converts to and from that `JSONValue` against the field definition. No new reducer: the section is
fields bound to `$store.input`, so the existing `BindingReducer`, `Reset` and `isModified` carry it.
The documentlink editor reuses the searchable picker currently buried in the filter feature, which
this plan moves out to `DocumentsFeature/DocumentPicker/`.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, `swift-dependencies`,
`swift-sharing`, Swift Testing, `swift-snapshot-testing`, Tuist, mise.

**Source spec:** `docs/superpowers/specs/2026-08-24-document-custom-field-editing-design.md`

## Global Constraints

- **Comments:** only `//`. Never `///`, never `/** */` — anywhere, including tests. Comment only
  when a future reader would otherwise stop and wonder why the code is the way it is. Do not restate
  what the code says. This is from `AGENTS.md` and it is absolute.
- **`@ViewAction` views send with `send`, never `store.send`.** `DocumentFormView` is annotated
  `@ViewAction(for: DocumentFormReducer.self)`, so every new call site in it uses `send(.x)`. Views
  that are *not* annotated — any new generic subview — use `store.send(.view(.x))`.
- **Confirmations use `ConfirmationPopupView` via a `@DependencyClient` presenter.** Never
  `.confirmationDialog`, `.alert`, or `ConfirmationDialogState`. (This plan needs no confirmation —
  detaching a field is undone by `Reset`. Noted so nobody adds one.)
- **Properties and initialiser parameters are alphabetical** in this codebase's models. Insert
  `customFields` between `created`/`createdDate` and `documentType`.
- **Minimum supported API is 8** (`ApiVersion.minimumSupported`). Select values are always the
  option's string id. No legacy integer-index branch.
- **Monetary, verified against the dev instance:** a bare integer like `"1234"` is accepted, but
  `"EUR1234"` is **rejected** — with a currency code present, a decimal point and 1–2 decimals are
  required. This design always emits a code, so the amount is normalised to exactly two decimals.
- **`null` is accepted as the value of every data type** — verified for string, boolean, select and
  documentlink. An empty editor sends `.null`, uniformly.
- **Targets use Xcode buildable folders.** A new `.swift` file inside an existing module directory
  is picked up with no `tuist generate` and no project-file edit.
- **Strings** go in `Shared/Framework/Resources/Localizable.xcstrings`, **`en` and `de` both**. The
  catalog has no untranslated key today.
- **Before every commit:** run `mise run format`, then `mise run ci:lint`.

**Test commands.** Full suite: `mise run ci:test`. Focused, which is what you want per step:

```bash
tuist test ApiInterface -d "iPhone 17 Pro" -- \
  -testLanguage en -testRegion DE \
  -only-testing:ApiInterfaceTests/DocumentCustomFieldTests
```

Swap the scheme (`ApiInterface`, `DocumentsFeature`) and the `-only-testing:` path per task.

**Snapshot tests record on first run.** `.snapshots(record: .environment)` reads `SNAPSHOT_RECORD`
and defaults to `.missing`: a snapshot with no recorded image is written to disk and the test
**fails once**. Run it a second time to confirm it passes, then eyeball the recorded PNG under
`Snapshots/` before committing it.

## File Structure

**Create**

| Path | Responsibility |
| --- | --- |
| `Modules/ApiInterface/Documents/DocumentCustomField.swift` | The wire pair `{field, value}` |
| `Modules/ApiInterfaceTests/Documents/DocumentCustomFieldTests.swift` | Value-shape decoding/encoding |
| `Modules/ApiInterfaceTests/Documents/UpdateDocumentInputTests.swift` | Payload encoding |
| `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift` | Typed editor state ↔ `JSONValue` |
| `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomField.swift` | `{id, value}` row in the input |
| `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldsView.swift` | Section: list, add menu, empty states |
| `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldRow.swift` | One row: `switch` over `dataType` |
| `Modules/DocumentsFeature/DocumentPicker/DocumentPicker*.swift` | The picker, moved out of the filter |
| `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/*Tests.swift` | Value, reducer and snapshot tests |

**Modify**

| Path | Change |
| --- | --- |
| `Modules/ApiInterface/Documents/Document.swift` | `customFields` property, coding, `testValue` |
| `Modules/ApiInterface/Documents/UpdateDocumentInput.swift` | `customFields` property, init, `testValue` |
| `Modules/DocumentsFeature/DocumentForm/DocumentFormInput.swift` | `customFields`, seeding, `apiValue` |
| `Modules/DocumentsFeature/DocumentForm/DocumentFormSection.swift` | `.customFields` case |
| `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift` | 3 view actions, picker destination, `@Shared` definitions |
| `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift` | 3 `switch`es on `section`, new section body |
| `Modules/DocumentsFeature/DocumentFilter/.../AtomEditor/*` | Use the moved picker |
| `Shared/Framework/Resources/Localizable.xcstrings` | New keys, en + de |

### Two corrections to the spec

The spec's part D named two components that do not fit. Use these instead:

- **`MenuField` cannot be used for select options or for the currency.** Its generic is
  `SelectionValue: CaseIterable` — it builds its picker from `allCases`, so it only works for
  compile-time enums. Select options and currency codes are runtime data. Use `Field` + `Picker`
  directly, exactly as `CustomFieldQueryAtomEditorView.stringField()` already does.
- **`URLField` cannot be used for a `url` custom field.** It binds a non-optional `URL`, requires a
  `FocusState` binding, and forces an `https://` / `http://` scheme picker — so it cannot represent
  the empty value, and it would rewrite whatever the server holds. Use `Field` + `TextField` with
  `.keyboardType(.URL)`, `.textInputAutocapitalization(.never)` and `.autocorrectionDisabled()`.

---

### Task 1: `DocumentCustomField` on the API model

**Files:**
- Create: `Modules/ApiInterface/Documents/DocumentCustomField.swift`
- Create: `Modules/ApiInterfaceTests/Documents/DocumentCustomFieldTests.swift`
- Create: `Modules/ApiInterfaceTests/Documents/UpdateDocumentInputTests.swift`
- Modify: `Modules/ApiInterface/Documents/Document.swift`
- Modify: `Modules/ApiInterface/Documents/UpdateDocumentInput.swift`
- Modify: `Modules/ApiInterfaceTests/Documents/DocumentTests.swift`

**Interfaces:**
- Consumes: `JSONValue` from `ApiInterface/Shared/JSONValue.swift`; `CustomField.Id`.
- Produces: `DocumentCustomField(field:value:)` with `.testValue(field:value:)`;
  `Document.customFields: [DocumentCustomField]`;
  `UpdateDocumentInput.init(archiveSerialNumber:content:correspondent:createdDate:customFields:documentType:storagePath:tags:title:)`.

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/Documents/DocumentCustomFieldTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentCustomFieldTests {

    @Test(
        arguments: [
            ("string", "\"Reference 42\"", JSONValue.string("Reference 42")),
            ("date", "\"2026-08-24\"", .string("2026-08-24")),
            ("monetary", "\"EUR1234.50\"", .string("EUR1234.50")),
            ("select", "\"G1btwlUUPsE9K3ta\"", .string("G1btwlUUPsE9K3ta")),
            ("boolean", "true", .bool(true)),
            ("integer", "7", .number(7)),
            ("float", "1.5", .number(1.5)),
            ("documentLink", "[2, 3]", .array([.number(2), .number(3)])),
            ("empty", "null", .null),
        ]
    )
    func decoding_readsEveryValueShape(name: String, json: String, expected: JSONValue) throws {
        let field = try JSONDecoder.apiDecoder.decode(
            DocumentCustomField.self,
            from: Data("{\"field\": 21, \"value\": \(json)}".utf8)
        )

        #expect(field.field == 21)
        #expect(field.value == expected)
    }

    // A value shape no known data type uses. It has to survive the round trip untouched, because a
    // save replaces the document's whole list and would otherwise blank fields of a type this app
    // does not yet know.
    @Test
    func encoding_roundTripsAnUnrecognisedValueShape() throws {
        let json = Data("{\"field\":21,\"value\":{\"nested\":[1,\"two\"]}}".utf8)

        let field = try JSONDecoder.apiDecoder.decode(DocumentCustomField.self, from: json)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(field)

        #expect(String(decoding: encoded, as: UTF8.self) == "{\"field\":21,\"value\":{\"nested\":[1,\"two\"]}}")
    }
}
```

Add to `Modules/ApiInterfaceTests/Documents/DocumentTests.swift` — inside the existing `struct
DocumentTests`, after the last `@Test`:

```swift
    @Test
    func decoding_readsCustomFields() throws {
        let document = try JSONDecoder.apiDecoder.decode(
            Document.self,
            from: Data(payload(created: "2023-12-06", createdDate: "2023-12-06", customFields: """
            "custom_fields": [{"field": 21, "value": "EUR1234.50"}],
            """).utf8)
        )

        #expect(document.customFields == [.testValue(field: 21, value: .string("EUR1234.50"))])
    }

    // Documents cached before custom fields existed have no such key.
    @Test
    func decoding_treatsAMissingCustomFieldsKeyAsEmpty() throws {
        let document = try JSONDecoder.apiDecoder.decode(
            Document.self,
            from: Data(payload(created: "2023-12-06", createdDate: "2023-12-06").utf8)
        )

        #expect(document.customFields.isEmpty)
    }
```

and widen the existing private helper in the same file to take the new entry:

```swift
    func payload(created: String, createdDate: String?, customFields: String = "") -> String {
        let createdDateEntry = createdDate.map { "\"created_date\": \"\($0)\"," } ?? ""
        return """
        {
            "added": "2023-12-07T09:30:00+01:00",
            "archive_serial_number": 42,
            "archived_file_name": "invoice.pdf",
            "content": "Some invoice",
            "correspondent": 1,
            "created": "\(created)",
            \(createdDateEntry)
            \(customFields)
            "document_type": 1,
            "id": 1,
            "modified": "2023-12-07T09:30:00+01:00",
            "original_file_name": "invoice.pdf",
            "owner": 1,
            "storage_path": 1,
            "tags": [1],
            "title": "Invoice"
        }
        """
    }
```

Create `Modules/ApiInterfaceTests/Documents/UpdateDocumentInputTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct UpdateDocumentInputTests {

    @Test
    func encoding_writesCustomFieldsUnderTheSnakeCaseKey() throws {
        let input = UpdateDocumentInput.testValue(customFields: [
            .testValue(field: 21, value: .string("EUR1234.50")),
            .testValue(field: 17, value: .null),
        ])

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        #expect(json.contains("\"custom_fields\""))
        #expect(json.contains("\"value\" : \"EUR1234.50\""))
        #expect(json.contains("\"value\" : null"))
    }

    // The server replaces the document's whole list with whatever is sent, so an empty array is how
    // every field is detached at once.
    @Test
    func encoding_writesAnEmptyArrayRatherThanOmittingTheKey() throws {
        let input = UpdateDocumentInput.testValue(customFields: [])

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        #expect(json.contains("\"custom_fields\" : ["))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tuist test ApiInterface -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: FAIL — `cannot find 'DocumentCustomField' in scope`, and `Document`/`UpdateDocumentInput`
have no `customFields`.

- [ ] **Step 3: Create `DocumentCustomField`**

`Modules/ApiInterface/Documents/DocumentCustomField.swift`:

```swift
import Foundation

public struct DocumentCustomField: Codable, Equatable, Hashable, Sendable {

    public let field: CustomField.Id

    public let value: JSONValue

    public init(
        field: CustomField.Id,
        value: JSONValue
    ) {
        self.field = field
        self.value = value
    }
}

public extension DocumentCustomField {

    static func testValue(
        field: CustomField.Id = 1,
        value: JSONValue = .string("Test")
    ) -> Self {
        .init(
            field: field,
            value: value
        )
    }
}
```

- [ ] **Step 4: Add `customFields` to `Document`**

In `Modules/ApiInterface/Documents/Document.swift`, four edits, all placing `customFields` between
`created` and `documentType`:

1. the stored property: `public let customFields: [DocumentCustomField]`
2. the memberwise `init` parameter and assignment
3. `CodingKeys` — add `customFields` to the `case created, createdDate, …` list
4. `init(from:)` and `encode(to:)`:

```swift
        customFields = try container.decodeIfPresent([DocumentCustomField].self, forKey: .customFields) ?? []
```

```swift
        try container.encode(customFields, forKey: .customFields)
```

5. `testValue` — `customFields: [DocumentCustomField] = []`, so no existing call site changes.

- [ ] **Step 5: Add `customFields` to `UpdateDocumentInput`**

In `Modules/ApiInterface/Documents/UpdateDocumentInput.swift`, between `createdDate` and
`documentType`, in the properties, the `init`, and `testValue` (defaulting to `[]`):

```swift
    public let customFields: [DocumentCustomField]
```

Not `@NullEncodable`: the array is never null, and its emptiness is meaningful.

The only non-test caller of the initialiser is `DocumentFormInput.apiValue(content:)` — pass `[]`
there for now; Task 3 replaces it.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
tuist test ApiInterface -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: PASS.

- [ ] **Step 7: Build the feature modules that consume `Document`**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: PASS. `Document.testValue` and `UpdateDocumentInput.testValue` both default the new
parameter, so nothing downstream should break. If something does, it is a call site using the
memberwise `init` directly — add `customFields:` there.

- [ ] **Step 8: Format, lint, commit**

```bash
mise run format && mise run ci:lint
git add Modules/ApiInterface Modules/ApiInterfaceTests
git commit -m "feat: carry custom field values on documents"
```

---

### Task 2: `DocumentFormCustomFieldValue`

The typed editor state and its conversion to and from `JSONValue`. Pure value type, no UI, no
reducer — the piece most worth getting exactly right, because every later task depends on its
round trip being stable.

**Files:**
- Create: `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift`
- Create: `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/DocumentFormCustomFieldValueTests.swift`

**Interfaces:**
- Consumes: `CustomField`, `CustomFieldDataType`, `CustomFieldExtraData`, `JSONValue`,
  `Document.Id`, `DocumentCustomField` (Task 1).
- Produces:
  - `enum DocumentFormCustomFieldValue` with cases `boolean(Bool)`, `date(Date?)`,
    `documentLink([Document.Id])`, `monetary(currency: String, amount: String)`, `number(String)`,
    `select(String?)`, `text(String)`, `unsupported(JSONValue)`
  - `init(field: CustomField, json: JSONValue)`
  - `static func empty(field: CustomField) -> Self`
  - `func json(field: CustomField) -> JSONValue`
  - `var validationError: LocalizedStringResource?`
  - `var isEditable: Bool`

- [ ] **Step 1: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/DocumentFormCustomFieldValueTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentFormCustomFieldValueTests {

    @Test
    func init_readsEachDataType() throws {
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .string), json: .string("Ref"))
                == .text("Ref")
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .boolean), json: .bool(true))
                == .boolean(true)
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .integer), json: .number(7))
                == .number("7")
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .float), json: .number(1.5))
                == .number("1.5")
        )
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .select), json: .string("abc"))
                == .select("abc")
        )
        #expect(
            DocumentFormCustomFieldValue(
                field: .testValue(dataType: .documentLink),
                json: .array([.number(2), .number(3)])
            ) == .documentLink([2, 3])
        )
    }

    // An integer arrives as a Double. Rendering 7.0 as "7.0" in a field the user then saves would
    // send a float where the server expects an int.
    @Test
    func init_rendersAnIntegerWithoutADecimalPoint() {
        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .integer), json: .number(7))
                == .number("7")
        )
    }

    @Test
    func init_readsADateAtNoonGmt() throws {
        let value = DocumentFormCustomFieldValue(
            field: .testValue(dataType: .date),
            json: .string("2026-08-24")
        )

        #expect(value == .date(Date(timeIntervalSince1970: 1_787_529_600)))
    }

    @Test
    func init_splitsAMonetaryValueIntoCurrencyAndAmount() {
        #expect(
            DocumentFormCustomFieldValue(
                field: .testValue(dataType: .monetary),
                json: .string("EUR1234.50")
            ) == .monetary(currency: "EUR", amount: "1234.50")
        )
    }

    // Another client may have stored a bare amount. The field's default currency fills the gap.
    @Test
    func init_fallsBackToTheFieldsDefaultCurrency() {
        #expect(
            DocumentFormCustomFieldValue(
                field: .testValue(dataType: .monetary, extraData: .init(defaultCurrency: "CHF")),
                json: .string("1234.50")
            ) == .monetary(currency: "CHF", amount: "1234.50")
        )
    }

    @Test
    func init_keepsAnUnknownDataTypeVerbatim() {
        let json = JSONValue.object(["nested": .number(1)])

        #expect(
            DocumentFormCustomFieldValue(field: .testValue(dataType: .unknown), json: json)
                == .unsupported(json)
        )
    }

    @Test
    func json_writesEachDataType() {
        #expect(DocumentFormCustomFieldValue.text("Ref")
            .json(field: .testValue(dataType: .string)) == .string("Ref"))
        #expect(DocumentFormCustomFieldValue.boolean(true)
            .json(field: .testValue(dataType: .boolean)) == .bool(true))
        #expect(DocumentFormCustomFieldValue.number("7")
            .json(field: .testValue(dataType: .integer)) == .number(7))
        #expect(DocumentFormCustomFieldValue.number("1.5")
            .json(field: .testValue(dataType: .float)) == .number(1.5))
        #expect(DocumentFormCustomFieldValue.select("abc")
            .json(field: .testValue(dataType: .select)) == .string("abc"))
        #expect(DocumentFormCustomFieldValue.documentLink([2, 3])
            .json(field: .testValue(dataType: .documentLink)) == .array([.number(2), .number(3)]))
        #expect(DocumentFormCustomFieldValue.date(Date(timeIntervalSince1970: 1_787_529_600))
            .json(field: .testValue(dataType: .date)) == .string("2026-08-24"))
    }

    // Verified against the server: "1234" alone is accepted, but "EUR1234" is a 400. A currency
    // code obliges the decimals, and this design always sends a code.
    @Test(
        arguments: [
            ("1234", "EUR1234.00"),
            ("1234.5", "EUR1234.50"),
            ("1234.50", "EUR1234.50"),
            ("-5", "EUR-5.00"),
        ]
    )
    func json_normalisesAMonetaryAmountToTwoDecimals(amount: String, expected: String) {
        let value = DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: amount)

        #expect(value.json(field: .testValue(dataType: .monetary)) == .string(expected))
    }

    @Test(
        arguments: [
            DocumentFormCustomFieldValue.text(""),
            .number(""),
            .date(nil),
            .select(nil),
            .documentLink([]),
            .monetary(currency: "EUR", amount: ""),
        ]
    )
    func json_writesNullForAnEmptyEditor(value: DocumentFormCustomFieldValue) {
        #expect(value.json(field: .testValue(dataType: .string)) == .null)
    }

    @Test
    func json_keepsAnUnsupportedValueVerbatim() {
        let json = JSONValue.object(["nested": .number(1)])

        #expect(DocumentFormCustomFieldValue.unsupported(json)
            .json(field: .testValue(dataType: .unknown)) == json)
    }

    // The property this whole design leans on: reading a value and writing it back unchanged must
    // produce the same JSON, or every document would open already "modified".
    @Test(
        arguments: [
            (CustomFieldDataType.string, JSONValue.string("Ref")),
            (.longText, .string("line one\nline two")),
            (.url, .string("https://example.com")),
            (.date, .string("2026-08-24")),
            (.boolean, .bool(true)),
            (.integer, .number(7)),
            (.float, .number(1.5)),
            (.monetary, .string("EUR1234.50")),
            (.select, .string("G1btwlUUPsE9K3ta")),
            (.documentLink, .array([.number(2), .number(3)])),
            (.unknown, .object(["nested": .number(1)])),
            (.string, .null),
        ]
    )
    func roundTrip_isStable(dataType: CustomFieldDataType, json: JSONValue) {
        let field = CustomField.testValue(dataType: dataType)

        #expect(DocumentFormCustomFieldValue(field: field, json: json).json(field: field) == json)
    }

    @Test(
        arguments: ["abc", "1.234", "1,5", "-", "1..2"]
    )
    func validationError_rejectsAnUnparseableNumber(amount: String) {
        #expect(DocumentFormCustomFieldValue.number(amount).validationError != nil)
        #expect(DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: amount)
            .validationError != nil)
    }

    @Test(
        arguments: ["", "0", "7", "1.5", "1.50", "-5.00"]
    )
    func validationError_acceptsAWellFormedNumber(amount: String) {
        #expect(DocumentFormCustomFieldValue.number(amount).validationError == nil)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE \
  -only-testing:DocumentsFeatureTests/DocumentFormCustomFieldValueTests
```

Expected: FAIL — `cannot find 'DocumentFormCustomFieldValue' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift`:

```swift
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
            self = .documentLink((json.arrayValue ?? []).compactMap { $0.intValue.map(Document.Id.init) })
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
```

Note the `.number("")` case: `Double("")` is nil, so an emptied numeric field sends `.null` — which
is exactly the "attached but empty" state.

- [ ] **Step 4: Add the `invalidNumber` string**

In `Shared/Framework/Resources/Localizable.xcstrings`, add a key `invalidNumber` with `en` =
`"Not a number"` and `de` = `"Keine Zahl"`, matching the shape of the existing entries (a
`localizations` object per language with `stringUnit` / `state: "translated"`).

- [ ] **Step 5: Run the tests to verify they pass**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE \
  -only-testing:DocumentsFeatureTests/DocumentFormCustomFieldValueTests
```

Expected: PASS, all cases. If `init_readsADateAtNoonGmt` fails on the timestamp, print the value the
formatter produced and fix the *expectation* — `1_787_529_600` is 2026-08-24T00:00:00Z.

- [ ] **Step 6: Format, lint, commit**

```bash
mise run format && mise run ci:lint
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Shared/Framework/Resources
git commit -m "feat: typed editor state for custom field values"
```

---

### Task 3: Carry the values through `DocumentFormInput`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomField.swift`
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormInput.swift`
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormSection.swift`
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift`
- Create: `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/DocumentFormInputCustomFieldsTests.swift`

**Interfaces:**
- Consumes: `DocumentFormCustomFieldValue` (Task 2), `Document.customFields` (Task 1).
- Produces:
  - `struct DocumentFormCustomField: Equatable, Identifiable, Sendable { let id: CustomField.Id; var value: DocumentFormCustomFieldValue }`
  - `DocumentFormInput.customFields: IdentifiedArrayOf<DocumentFormCustomField>`
  - `DocumentFormInput.hasInvalidCustomField: Bool`
  - `DocumentFormSection.customFields`
  - `DocumentFormReducer.State.customFields: IdentifiedArrayOf<CustomField>` (`@Shared`)

- [ ] **Step 1: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/DocumentFormInputCustomFieldsTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Foundation
import IdentifiedCollections
import Testing
import TestSupport

@Suite(
    .dependencies {
        $0.apiCache.customField = { id, _ in
            [CustomField].previewValue.first { $0.id == id }
        }
    }
)
struct DocumentFormInputCustomFieldsTests {

    @Test
    func init_seedsTheDocumentsFieldsInOrder() {
        let input = DocumentFormInput(
            document: .testValue(customFields: [
                .testValue(field: 2, value: .string("2026-08-24")),
                .testValue(field: 1, value: .string("Ref")),
            ]),
            server: .testValue()
        )

        #expect(input.customFields.ids == [2, 1])
        #expect(input.customFields[id: 1]?.value == .text("Ref"))
    }

    // A definition the cache does not know cannot be rendered or converted, and guessing a type
    // would corrupt the value on save.
    @Test
    func init_dropsAFieldWithNoKnownDefinition() {
        let input = DocumentFormInput(
            document: .testValue(customFields: [.testValue(field: 999, value: .string("Ref"))]),
            server: .testValue()
        )

        #expect(input.customFields.isEmpty)
    }

    @Test
    func apiValue_writesTheFieldsBackInOrder() {
        let input = DocumentFormInput(
            document: .testValue(customFields: [
                .testValue(field: 1, value: .string("Ref")),
                .testValue(field: 3, value: .bool(true)),
            ]),
            server: .testValue()
        )

        #expect(input.apiValue(content: nil).customFields == [
            .testValue(field: 1, value: .string("Ref")),
            .testValue(field: 3, value: .bool(true)),
        ])
    }

    // The whole design rests on this: both sides of `isModified` derive from the same document, so
    // an untouched sheet must compare equal for every data type.
    @Test
    func roundTrip_leavesAnUntouchedDocumentUnmodified() {
        let document = Document.testValue(customFields: [
            .testValue(field: 1, value: .string("Ref")),
            .testValue(field: 2, value: .string("2026-08-24")),
            .testValue(field: 3, value: .bool(true)),
            .testValue(field: 4, value: .string("EUR1234.50")),
            .testValue(field: 5, value: .string("aqgT3m4XZw8aw3Ou")),
        ])
        let server = Server.testValue()

        #expect(
            DocumentFormInput(document: document, server: server)
                == DocumentFormInput(document: document, server: server)
        )
        #expect(DocumentFormInput(document: document, server: server)
            .apiValue(content: nil).customFields == document.customFields)
    }

    @Test
    func hasInvalidCustomField_isTrueForAnUnparseableNumber() {
        var input = DocumentFormInput(document: .testValue(), server: .testValue())
        input.customFields = [.init(id: 1, value: .number("abc"))]

        #expect(input.hasInvalidCustomField)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE \
  -only-testing:DocumentsFeatureTests/DocumentFormInputCustomFieldsTests
```

Expected: FAIL — `DocumentFormInput` has no `customFields`.

- [ ] **Step 3: Create the row type**

`Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomField.swift`:

```swift
import ApiInterface
import Foundation

// The field id, not the CustomField: the definition is read from the cache at render time, so a
// rename on the server cannot register as an unsaved edit on an open sheet.
struct DocumentFormCustomField: Equatable, Identifiable, Sendable {

    let id: CustomField.Id

    var value: DocumentFormCustomFieldValue
}
```

- [ ] **Step 4: Extend `DocumentFormInput`**

In `Modules/DocumentsFeature/DocumentForm/DocumentFormInput.swift`:

Add the import `import IdentifiedCollections`, the property (alphabetically, after
`createdDate`):

```swift
    var customFields = IdentifiedArrayOf<DocumentFormCustomField>()
```

Seed it in `init(document:server:)`:

```swift
        customFields = IdentifiedArray(
            uniqueElements: document.customFields.compactMap { stored in
                guard let field = stored.field.get(server) else {
                    return nil
                }
                return DocumentFormCustomField(
                    id: field.id,
                    value: DocumentFormCustomFieldValue(field: field, json: stored.value)
                )
            }
        )
```

Pass it in `apiValue(content:)` — replacing the `[]` placeholder from Task 1:

```swift
            customFields: customFields.compactMap { row in
                guard let field = row.id.get(server) else {
                    return nil
                }
                return DocumentCustomField(field: field.id, value: row.value.json(field: field))
            },
```

`apiValue` has no `server` today — add a `server: Server` parameter and update the one call site in
`DocumentFormReducer+Effect.runUpdateDocument`, which already has `state.server` to hand. Also add
the validation flag:

```swift
    var hasInvalidCustomField: Bool {
        customFields.contains { $0.value.validationError != nil }
    }
```

- [ ] **Step 5: Add the section case**

In `Modules/DocumentsFeature/DocumentForm/DocumentFormSection.swift`, add `case customFields` to the
enum and to `description` — `String(localized: .customFields)`, a key that already exists. Note
`CaseIterable` order determines the ⋯ menu order and the enum is declared alphabetically
(`content`, `customFields`, `details`, `notes`), which reads correctly.

- [ ] **Step 6: Give the reducer the definitions**

In `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift`, alongside the existing
`@Shared` caches at the bottom of `State`:

```swift
        @Shared
        var customFields: IdentifiedArrayOf<CustomField>
```

and in `init`, alongside the others:

```swift
            self._customFields = Shared(wrappedValue: [], .customFields(server))
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: PASS — the new suite and every existing `DocumentFormReducerTests` case.

- [ ] **Step 8: Format, lint, commit**

```bash
mise run format && mise run ci:lint
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: stage custom field values in the document form input"
```

---

### Task 4: Move the document picker out of the filter feature

Pure refactor, no behaviour change. Doing it before the form needs it keeps the move reviewable on
its own.

**Files:**
- Move: `Modules/DocumentsFeature/DocumentFilter/CustomField/Cards/AtomEditor/DocumentPicker/` → `Modules/DocumentsFeature/DocumentPicker/`
- Move: `Modules/DocumentsFeatureTests/DocumentFilter/CustomField/Cards/AtomEditor/DocumentPicker/` → `Modules/DocumentsFeatureTests/DocumentPicker/`
- Move: `Snapshots/DocumentsFeatureTests/CustomFieldQueryDocumentPickerViewTests/` → `Snapshots/DocumentsFeatureTests/DocumentPickerViewTests/`
- Modify: `Modules/DocumentsFeature/DocumentFilter/CustomField/Cards/AtomEditor/CustomFieldQueryAtomEditorReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/CustomField/Cards/AtomEditor/CustomFieldQueryAtomEditorView.swift`
- Modify: `Modules/DocumentsFeatureTests/DocumentFilter/CustomField/Cards/AtomEditor/CustomFieldQueryAtomEditorReducerTests.swift`

**Interfaces:**
- Produces: `DocumentPickerReducer` (`.State`, `.Action`, `.State.testValue(…)` — same signatures as
  before, only the type name changes), `DocumentPickerView`.

- [ ] **Step 1: Move the files with git**

```bash
git mv Modules/DocumentsFeature/DocumentFilter/CustomField/Cards/AtomEditor/DocumentPicker \
       Modules/DocumentsFeature/DocumentPicker
git mv Modules/DocumentsFeatureTests/DocumentFilter/CustomField/Cards/AtomEditor/DocumentPicker \
       Modules/DocumentsFeatureTests/DocumentPicker
git mv Snapshots/DocumentsFeatureTests/CustomFieldQueryDocumentPickerViewTests \
       Snapshots/DocumentsFeatureTests/DocumentPickerViewTests
```

Then rename each file, dropping the `CustomFieldQuery` prefix:
`DocumentPickerReducer.swift`, `DocumentPickerReducer+Effect.swift`,
`DocumentPickerReducer+TestValue.swift`, `DocumentPickerView.swift`,
`DocumentPickerReducerTests.swift`, `DocumentPickerViewTests.swift`.

- [ ] **Step 2: Rename the types**

```bash
grep -rl "CustomFieldQueryDocumentPicker" Modules/ | \
  xargs sed -i '' 's/CustomFieldQueryDocumentPicker/DocumentPicker/g'
```

Then check the two atom-editor files by hand: the state property is
`var documentPicker: DocumentPickerReducer.State?` and the action case is `documentPicker` — both
already carry that name, so only the type changed.

- [ ] **Step 3: Run the tests**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: PASS, **including the moved snapshot tests without re-recording**. The recorded PNGs moved
with the suite, so any snapshot failure here is a real regression from the rename — investigate it,
do not re-record.

- [ ] **Step 4: Format, lint, commit**

```bash
mise run format && mise run ci:lint
git add -A Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots
git commit -m "refactor: lift the document picker out of the filter feature"
```

---

### Task 5: Reducer actions for attach, detach and linking

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift`
- Modify: `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentFormCustomField`, `DocumentFormCustomFieldValue.empty(field:)` (Tasks 2–3),
  `DocumentPickerReducer` (Task 4).
- Produces, on `DocumentFormReducer.Action.View`:
  - `case addCustomFieldTapped(CustomField.Id)`
  - `case removeCustomFieldTapped(CustomField.Id)`
  - `case documentLinkTapped(CustomField.Id)`
  - on `Destination`: `case documentPicker(DocumentPickerReducer)`
  - on `State`: `var documentLinkFieldId: CustomField.Id?`

- [ ] **Step 1: Write the failing tests**

Append to `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormReducerTests.swift`:

```swift
    @Test
    func test_view_addCustomFieldTapped() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        } withDependencies: {
            $0.apiCache.customField = { id, _ in [CustomField].previewValue.first { $0.id == id } }
        }
        store.state.$customFields.withLock { $0 = IdentifiedArray(uniqueElements: .previewValue) }

        await store.send(.view(.addCustomFieldTapped(1))) {
            $0.input.customFields = [.init(id: 1, value: .text(""))]
        }
    }

    // A boolean has no empty state a Toggle could show, so it attaches as a definite No.
    @Test
    func test_view_addCustomFieldTapped_booleanStartsFalse() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue()) {
            DocumentFormReducer()
        } withDependencies: {
            $0.apiCache.customField = { id, _ in [CustomField].previewValue.first { $0.id == id } }
        }
        store.state.$customFields.withLock { $0 = IdentifiedArray(uniqueElements: .previewValue) }

        await store.send(.view(.addCustomFieldTapped(3))) {
            $0.input.customFields = [.init(id: 3, value: .boolean(false))]
        }
    }

    @Test
    func test_view_addCustomFieldTapped_ignoresAFieldAlreadyAttached() async throws {
        var state = DocumentFormReducer.State.testValue()
        state.input.customFields = [.init(id: 1, value: .text("Ref"))]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        } withDependencies: {
            $0.apiCache.customField = { id, _ in [CustomField].previewValue.first { $0.id == id } }
        }
        store.state.$customFields.withLock { $0 = IdentifiedArray(uniqueElements: .previewValue) }

        await store.send(.view(.addCustomFieldTapped(1)))
    }

    @Test
    func test_view_removeCustomFieldTapped() async throws {
        var state = DocumentFormReducer.State.testValue()
        state.input.customFields = [
            .init(id: 1, value: .text("Ref")),
            .init(id: 3, value: .boolean(true)),
        ]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.view(.removeCustomFieldTapped(1))) {
            $0.input.customFields = [.init(id: 3, value: .boolean(true))]
        }
    }

    @Test
    func test_view_documentLinkTapped() async throws {
        var state = DocumentFormReducer.State.testValue()
        state.input.customFields = [.init(id: 6, value: .documentLink([]))]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(.view(.documentLinkTapped(6))) {
            $0.documentLinkFieldId = 6
            $0.destination = .documentPicker(.init(selection: [], server: state.server))
        }
    }

    @Test
    func test_destination_documentPicker_delegate_selected() async throws {
        var state = DocumentFormReducer.State.testValue()
        state.input.customFields = [.init(id: 6, value: .documentLink([]))]
        state.documentLinkFieldId = 6
        state.destination = .documentPicker(.init(selection: [], server: state.server))
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }

        await store.send(
            .destination(.presented(.documentPicker(.delegate(.selected([.testValue(id: 2)])))))
        ) {
            $0.destination = nil
            $0.documentLinkFieldId = nil
            $0.input.customFields[id: 6]?.value = .documentLink([2])
        }
    }
```

Add `.previewValue` for the definitions — it already exists on `Array<CustomField>` with ids 1–5 for
string, date, boolean, monetary and select. Add a documentlink entry with id 6 to that array in
`Modules/ApiInterface/CustomFields/CustomField.swift`:

```swift
            .testValue(dataType: .documentLink, documentCount: 18, id: 6, name: "Related")
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE \
  -only-testing:DocumentsFeatureTests/DocumentFormReducerTests
```

Expected: FAIL — no `addCustomFieldTapped` case.

- [ ] **Step 3: Add the actions, destination and state**

In `DocumentFormReducer.Action.View`, alphabetically among the existing cases:

```swift
            case addCustomFieldTapped(CustomField.Id)
            case documentLinkTapped(CustomField.Id)
            case removeCustomFieldTapped(CustomField.Id)
```

In `Destination`:

```swift
        case documentPicker(DocumentPickerReducer)
```

In `State`, next to `destination`:

```swift
        var documentLinkFieldId: CustomField.Id?
```

- [ ] **Step 4: Handle them in the reducer**

In the `.view(viewAction)` switch:

```swift
                case let .addCustomFieldTapped(id):
                    guard state.input.customFields[id: id] == nil,
                          let field = state.customFields[id: id]
                    else {
                        return .none
                    }
                    state.input.customFields.append(
                        DocumentFormCustomField(id: id, value: .empty(field: field))
                    )
                    return .none
                case let .documentLinkTapped(id):
                    guard case let .documentLink(ids) = state.input.customFields[id: id]?.value else {
                        return .none
                    }
                    state.documentLinkFieldId = id
                    state.destination = .documentPicker(DocumentPickerReducer.State(
                        selection: IdentifiedArray(uniqueElements: ids.compactMap { $0.get(state.server) }),
                        server: state.server
                    ))
                    return .none
                case let .removeCustomFieldTapped(id):
                    state.input.customFields.remove(id: id)
                    return .none
```

and alongside the other destination delegates:

```swift
            case let .destination(.presented(.documentPicker(.delegate(.selected(documents))))):
                defer { state.documentLinkFieldId = nil }
                state.destination = nil
                guard let id = state.documentLinkFieldId else {
                    return .none
                }
                state.input.customFields[id: id]?.value = .documentLink(documents.map(\.id))
                return .none
```

Check the picker's actual delegate case name and payload in
`Modules/DocumentsFeature/DocumentPicker/DocumentPickerReducer.swift` and match it — the atom editor
already consumes it, so copy that call site rather than guessing. If the picker reports its
selection through binding rather than a delegate, mirror whatever the atom editor does and adjust
the test in Step 1 to match.

`Document.Id.get(_:)` may not exist; if not, resolve the titles the way the atom editor does, via
`getDocumentsByIds`, and seed the picker with an empty selection plus the ids.

- [ ] **Step 5: Gate Save on validity**

In `DocumentFormView.buttons()`, the Save button's `.disabled(!store.isModified)` becomes:

```swift
            .disabled(!store.isModified || store.input.hasInvalidCustomField)
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: PASS.

- [ ] **Step 7: Format, lint, commit**

```bash
mise run format && mise run ci:lint
git add Modules/ApiInterface Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: attach and detach custom fields on a document"
```

---

### Task 6: The section, with the simple editors

Section shell, add menu, remove control, empty states, and the editors for `string`, `longtext`,
`url`, `integer`, `float`, `boolean` and `date`. The three that need more scaffolding land in
Task 7; until then their rows fall through to a read-only placeholder.

**Files:**
- Create: `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldsView.swift`
- Create: `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldRow.swift`
- Create: `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/DocumentFormCustomFieldsViewTests.swift`
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift`
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: everything from Tasks 2, 3 and 5.
- Produces: `DocumentFormCustomFieldsView(store:)` and `DocumentFormCustomFieldRow(field:value:onRemove:onDocumentLinkTapped:)`.

- [ ] **Step 1: Add the strings**

In `Shared/Framework/Resources/Localizable.xcstrings`, add with `en` and `de` both:

| key | en | de |
| --- | --- | --- |
| `addCustomField` | Add field | Feld hinzufügen |
| `removeCustomField` | Remove field | Feld entfernen |
| `noCustomFieldsDefined` | This server has no custom fields | Dieser Server hat keine benutzerdefinierten Felder |
| `noCustomFieldsAttached` | No fields on this document yet | Noch keine Felder an diesem Dokument |
| `currency` | Currency | Währung |

(`invalidNumber` and `customFields` already exist — `invalidNumber` from Task 2.)

- [ ] **Step 2: Write the failing snapshot tests**

Create `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/DocumentFormCustomFieldsViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import IdentifiedCollections
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.apiCache.customField = { id, _ in [CustomField].previewValue.first { $0.id == id } }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentFormCustomFieldsViewTests {

    @Test(
        arguments: [
            ("noneDefined", [CustomField](), [DocumentFormCustomField]()),
            ("noneAttached", .previewValue, []),
            ("simpleTypes", .previewValue, [
                DocumentFormCustomField(id: 1, value: .text("Invoice 2026-08")),
                DocumentFormCustomField(id: 2, value: .date(Date(timeIntervalSince1970: 1_787_529_600))),
                DocumentFormCustomField(id: 3, value: .boolean(true)),
            ]),
            ("invalidNumber", .previewValue, [
                DocumentFormCustomField(id: 1, value: .text("Ref")),
                DocumentFormCustomField(id: 7, value: .number("abc")),
            ]),
            ("unsupported", .previewValue, [
                DocumentFormCustomField(id: 8, value: .unsupported(.string("something new"))),
            ]),
        ]
    )
    func snapshot(
        name: String,
        definitions: [CustomField],
        attached: [DocumentFormCustomField]
    ) async throws {
        var state = DocumentFormReducer.State.testValue(section: .customFields)
        state.input.customFields = IdentifiedArray(uniqueElements: attached)
        state.$customFields.withLock { $0 = IdentifiedArray(uniqueElements: definitions) }

        assertSnapshot(
            of: DocumentFormView(
                store: Store(initialState: state) {
                    EmptyReducer()
                }
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }
}
```

Add the two definitions the fixtures reference to `[CustomField].previewValue` in
`Modules/ApiInterface/CustomFields/CustomField.swift`:

```swift
            .testValue(dataType: .integer, documentCount: 21, id: 7, name: "Pages"),
            .testValue(dataType: .unknown, documentCount: 24, id: 8, name: "Future type")
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE \
  -only-testing:DocumentsFeatureTests/DocumentFormCustomFieldsViewTests
```

Expected: FAIL — `cannot find 'DocumentFormCustomFieldsView'`, and `.customFields` is not a case of
`DocumentFormSection` in `DocumentFormView`'s switch yet.

- [ ] **Step 4: Write the row view**

`Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldRow.swift`:

```swift
import ApiInterface
import Components
import SwiftUI

struct DocumentFormCustomFieldRow: View {

    var body: some View {
        HStack(alignment: .center, spacing: .x2) {
            editor()

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.m3OnSurfaceVariant)
                    .accessibilityLabel(.removeCustomField)
            }
            .buttonStyle(.borderless)
        }
    }

    let field: CustomField

    @Binding
    var value: DocumentFormCustomFieldValue

    let onDocumentLinkTapped: () -> Void

    let onRemove: () -> Void

    @ViewBuilder
    private func editor() -> some View {
        switch field.dataType {
        case .boolean:
            booleanEditor()
        case .date:
            DateField(
                title: .init(stringLiteral: field.name),
                value: dateBinding(),
                suggestions: .constant([])
            )
        case .float, .integer:
            numberEditor()
        case .longText:
            longTextEditor()
        case .string, .url:
            textEditor()
        case .documentLink, .monetary, .select, .unknown:
            readOnlyEditor()
        }
    }

    @ViewBuilder
    private func booleanEditor() -> some View {
        Field(.init(stringLiteral: field.name)) {
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
                    Text(.init(stringLiteral: field.name))
                }
                .labelsHidden()

                Spacer()
            }
        }
        .tint(Color.m3Primary)
    }

    @ViewBuilder
    private func numberEditor() -> some View {
        Field(.init(stringLiteral: field.name), error: .constant(errorText)) {
            TextField(field.name, text: textBinding())
                .keyboardType(field.dataType == .integer ? .numberPad : .decimalPad)
                .textFieldStyle(.plain)
        }
    }

    @ViewBuilder
    private func textEditor() -> some View {
        Field(.init(stringLiteral: field.name)) {
            TextField(field.name, text: textBinding())
                .autocorrectionDisabled(field.dataType == .url)
                .keyboardType(field.dataType == .url ? .URL : .default)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(field.dataType == .url ? .never : .sentences)
        }
    }

    @ViewBuilder
    private func longTextEditor() -> some View {
        Field(.init(stringLiteral: field.name), padding: .x3) {
            TextEditor(text: textBinding())
                .frame(minHeight: 88)
                .font(.body)
                .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func readOnlyEditor() -> some View {
        Field(.init(stringLiteral: field.name)) {
            HStack {
                Text(verbatim: "—")
                    .foregroundColor(.m3OnSurfaceVariant)
                Spacer()
            }
        }
    }

    private var errorText: String? {
        value.validationError.map { String(localized: $0) }
    }

    private func dateBinding() -> Binding<Date> {
        Binding(
            get: {
                guard case let .date(date) = value, let date else {
                    return .now
                }
                return date
            },
            set: { value = .date($0) }
        )
    }

    private func textBinding() -> Binding<String> {
        Binding(
            get: {
                switch value {
                case let .number(text): text
                case let .text(text): text
                default: ""
                }
            },
            set: { text in
                switch value {
                case .number: value = .number(text)
                default: value = .text(text)
                }
            }
        )
    }
}
```

Check `Field`'s error API before wiring `error:` — the initialiser shown in
`Modules/Components/Field/Generic/Field.swift` takes `_ title` and `padding` and sets
`_error = .constant(nil)`. If there is no public initialiser taking an error binding, add one
mirroring the existing signature with an `error: Binding<String?>` parameter; the view body already
renders `error`. `DateField`'s and `Field`'s real signatures win over what is written here.

- [ ] **Step 5: Write the section view**

`Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldsView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import IdentifiedCollections
import SwiftUI

struct DocumentFormCustomFieldsView: View {

    var body: some View {
        if store.customFields.isEmpty {
            EmptyListView(
                systemImage: "list.bullet.rectangle",
                title: .noCustomFieldsDefined
            )
        } else {
            VStack(spacing: .x3) {
                ForEach($store.input.customFields) { $row in
                    if let field = store.customFields[id: row.id] {
                        DocumentFormCustomFieldRow(
                            field: field,
                            value: $row.value,
                            onDocumentLinkTapped: { store.send(.view(.documentLinkTapped(row.id))) },
                            onRemove: { store.send(.view(.removeCustomFieldTapped(row.id))) }
                        )
                    }
                }

                if store.input.customFields.isEmpty {
                    Text(.noCustomFieldsAttached)
                        .font(.subheadline)
                        .foregroundColor(.m3OnSurfaceVariant)
                }

                addMenu()
            }
            .frame(maxWidth: .infinity)
        }
    }

    @Bindable
    var store: StoreOf<DocumentFormReducer>

    private var unattached: [CustomField] {
        store.customFields.filter { store.input.customFields[id: $0.id] == nil }
    }

    @ViewBuilder
    private func addMenu() -> some View {
        Menu {
            ForEach(unattached) { field in
                Button(field.name) {
                    store.send(.view(.addCustomFieldTapped(field.id)))
                }
            }
        } label: {
            Label(.addCustomField, systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondary())
        .disabled(unattached.isEmpty)
    }
}
```

This view is **not** `@ViewAction`-annotated, so `store.send(.view(…))` is correct here — the same
exception `DocumentBulkEditGenericValueView` relies on.

- [ ] **Step 6: Wire the section into `DocumentFormView`**

Three `switch`es on `store.section` in `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift`
need the new case, and missing one is the likely bug:

1. `Sheet(isScrollingEnabled:)` — currently `store.section == .details`. The list scrolls, so:
   `isScrollingEnabled: store.section == .details || store.section == .customFields`
2. `Sheet(padding:)` — `.notes` gets `0`, everything else `.x4`. No change needed, but confirm the
   expression covers the new case rather than falling into the `0` branch.
3. the `content:` switch — add:

```swift
            case .customFields:
                DocumentFormCustomFieldsView(store: store)
```

4. the `bottom:` switch — add `.customFields` to the `.details, .content` arm so it gets Reset and
   Save rather than the note composer.

- [ ] **Step 7: Run the tests, twice**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE \
  -only-testing:DocumentsFeatureTests/DocumentFormCustomFieldsViewTests
```

Expected: FAIL on the first run — snapshots are recorded because none exist. Look at the five PNGs
written under `Snapshots/DocumentsFeatureTests/DocumentFormCustomFieldsViewTests/` and check each
renders what its name claims. Then run the same command again; expected: PASS.

- [ ] **Step 8: Run the whole module**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: PASS. `DocumentFormViewTests` snapshots must be unchanged — the details section did not
move.

- [ ] **Step 9: Format, lint, commit**

```bash
mise run format && mise run ci:lint
git add Modules Shared Snapshots
git commit -m "feat: edit simple custom field values on a document"
```

---

### Task 7: The monetary, select and documentlink editors

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldRow.swift`
- Modify: `Modules/DocumentsFeatureTests/DocumentForm/CustomFields/DocumentFormCustomFieldsViewTests.swift`

**Interfaces:**
- Consumes: `DocumentPickerReducer` (Task 4), `documentLinkTapped` (Task 5),
  `CustomFieldExtraData.selectOptions`, `DocumentFormCustomFieldValue.monetary/select/documentLink`.
- Produces: no new API. The `.documentLink, .monetary, .select` arm of `editor()` stops falling
  through to `readOnlyEditor()`; `.unknown` keeps falling through, which is the point.

- [ ] **Step 1: Add the failing snapshot cases**

In `DocumentFormCustomFieldsViewTests.swift`, extend the `arguments:` array:

```swift
            ("richTypes", .previewValue, [
                DocumentFormCustomField(id: 4, value: .monetary(currency: "EUR", amount: "1234.50")),
                DocumentFormCustomField(id: 5, value: .select("aqgT3m4XZw8aw3Ou")),
                DocumentFormCustomField(id: 6, value: .documentLink([2, 3])),
            ]),
            ("richTypesEmpty", .previewValue, [
                DocumentFormCustomField(id: 4, value: .monetary(currency: "EUR", amount: "")),
                DocumentFormCustomField(id: 5, value: .select(nil)),
                DocumentFormCustomField(id: 6, value: .documentLink([])),
            ]),
            ("invalidAmount", .previewValue, [
                DocumentFormCustomField(id: 4, value: .monetary(currency: "EUR", amount: "1.234")),
            ]),
```

- [ ] **Step 2: Run to verify they fail**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE \
  -only-testing:DocumentsFeatureTests/DocumentFormCustomFieldsViewTests
```

Expected: FAIL — three new snapshots record, and each shows the `—` placeholder instead of an
editor. Delete those three recorded PNGs before implementing, or they become the baseline.

- [ ] **Step 3: Implement the three editors**

In `DocumentFormCustomFieldRow`, replace the fall-through arm:

```swift
        case .documentLink:
            documentLinkEditor()
        case .monetary:
            monetaryEditor()
        case .select:
            selectEditor()
        case .unknown:
            readOnlyEditor()
```

and add:

```swift
    @ViewBuilder
    private func monetaryEditor() -> some View {
        Field(.init(stringLiteral: field.name), error: .constant(errorText)) {
            HStack(spacing: .x2) {
                Picker("", selection: currencyBinding()) {
                    ForEach(Self.currencyCodes, id: \.self) { code in
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
    }

    @ViewBuilder
    private func selectEditor() -> some View {
        Field(.init(stringLiteral: field.name)) {
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
        Field(.init(stringLiteral: field.name)) {
            HStack(spacing: .x3) {
                if linkedIds.isEmpty {
                    Text(verbatim: "—")
                        .foregroundColor(.m3OnSurfaceVariant)
                    Spacer()
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: .x3) {
                            ForEach(linkedIds, id: \.self) { id in
                                Text(linkedTitles[id] ?? "#\(id.rawValue)")
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
```

with the supporting members:

```swift
    // The codes the field defaults are drawn from, plus whatever the server already holds, so a
    // value written elsewhere is never silently rewritten to another currency.
    private static let currencyCodes: [String] = Locale.commonISOCurrencyCodes

    private var linkedIds: [Document.Id] {
        guard case let .documentLink(ids) = value else {
            return []
        }
        return ids
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
```

`linkedTitles` is a `[Document.Id: String]` passed in by the section view. Add it as a `let` on the
row and thread it from `DocumentFormCustomFieldsView`, which reads it from
`store.linkedCustomFieldDocuments` — a `IdentifiedArrayOf<Document>` on `DocumentFormReducer.State`
populated on `.onAppear` by an effect mirroring
`CustomFieldQueryAtomEditorReducer+Effect.runResolveLinkedDocuments`: collect every id across
`input.customFields`' `.documentLink` values, call `getDocumentsByIds`, store the result. An id that
does not come back stays rendered as `#42`.

If `Locale.commonISOCurrencyCodes` does not contain a code the server already holds, prepend it —
otherwise the `Picker` has no matching tag and renders blank:

```swift
    private var currencyOptions: [String] {
        guard case let .monetary(currency, _) = value, !Self.currencyCodes.contains(currency) else {
            return Self.currencyCodes
        }
        return [currency] + Self.currencyCodes
    }
```

Use `currencyOptions` in the `ForEach`.

- [ ] **Step 4: Add the reducer test for the resolved titles**

In `DocumentFormReducerTests`:

```swift
    @Test
    func test_view_onAppear_resolvesLinkedCustomFieldDocuments() async throws {
        var state = DocumentFormReducer.State.testValue(content: "loaded")
        state.input.customFields = [.init(id: 6, value: .documentLink([2]))]
        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { _, _ in [.testValue(id: 2, title: "Related")] }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.linkedCustomFieldDocuments) {
            $0.linkedCustomFieldDocuments = [.testValue(id: 2, title: "Related")]
        }
    }
```

`.onAppear` currently returns early when `content != nil`; the resolve effect must run regardless,
so merge it rather than putting it behind that guard.

- [ ] **Step 5: Run the tests, twice**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: first run records the three new snapshots and fails; inspect the PNGs — `richTypes` must
show a currency menu with an amount, a select menu showing `Open`, and two document capsules. Second
run: PASS.

- [ ] **Step 6: Verify against the real server**

```bash
mise run docker:start
```

Build and run the app against `http://localhost:8000` (`admin` / `T0PS3CR3T!!123`), open a document,
add one field of each type, save, and confirm the values come back after a pull-to-refresh. Pay
attention to a monetary field with a whole amount — type `1234`, save, and confirm it stores as
`EUR1234.00` rather than returning a 400.

- [ ] **Step 7: Format, lint, commit**

```bash
mise run format && mise run ci:lint
git add Modules Snapshots
git commit -m "feat: edit monetary, select and linked-document custom fields"
```

---

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: API layer → Task 1; form state → Tasks
2–3; reducer → Task 5; views → Tasks 6–7; the picker refactor → Task 4; strings → Tasks 2 and 6;
tests are folded into the task that produces the code they cover. The one spec bullet deliberately
contradicted is part D's component list — `MenuField` and `URLField` do not fit, and the reason is
recorded under "Two corrections to the spec".

**Known soft spots**, flagged rather than hidden:

- Task 5 Step 4 depends on `DocumentPickerReducer`'s delegate shape, which this plan did not read in
  full. The step says to copy the atom editor's call site and adjust the test to match.
- Task 6 Step 4 uses a `Field(_:error:)` initialiser that may not exist publicly; the step says to
  add it, mirroring the existing one, since `Field`'s body already renders `error`.
- Task 7 introduces `linkedCustomFieldDocuments` on the reducer state, which is state the spec did
  not name. It is the direct analogue of the atom editor's `linkedDocuments` and exists for the same
  reason: capsules need titles, not ids.
